# -*- coding: utf-8 -*-
class MainApp < Sinatra::Base
  namespace '/api/application_flow' do

    before do
      auth
    end

    # 申込フロー一覧取得
    get '/list' do
      content_type :json

      # 締切後 AND 参加者がいる AND 開催日前 の大会
      today = Date.today
      events = Event.where(kind: Event.kind__contest)
        .where { deadline < today }
        .where { participant_count > 0 }
        .where { (date.nil?) | (date >= today) }

      # 管理者以外は自分が申し込んだ大会のみ
      unless @user.admin || @user.permission.include?(:sub_admin)
        event_ids = EventUserChoice.where(user: @user)
          .select_map(:event_choice_id)
          .then { |choice_ids| EventChoice.where(id: choice_ids).select_map(:event_id) }
        events = events.where(id: event_ids)
      end

      flows = events.order(Sequel.asc(:date)).map do |event|
        flow = EventApplicationFlow.find_or_create(event_id: event.id)

        {
          event_id: event.id,
          event_name: event.name,
          event_date: event.date,
          deadline: event.deadline,
          participant_count: event.participant_count,
          current_step: flow.current_step,
          current_step_name: flow.current_step_name,
          editable: @user.admin || @user.permission.include?(:sub_admin)
        }
      end

      { flows: flows }.to_json
    end

    # 申込フロー詳細取得
    get '/detail/:event_id' do
      content_type :json
      event_id = params[:event_id].to_i
      event = Event[event_id]

      halt 404, { error: 'Event not found' }.to_json unless event

      # 権限チェック: 管理者または申込済みユーザーのみ
      unless @user.admin || @user.permission.include?(:sub_admin)
        user_choice = EventUserChoice.where(user: @user)
          .where(event_choice: event.choices_dataset.where(positive: true))
          .first
        halt 403, { error: 'Forbidden' }.to_json unless user_choice
      end

      flow = EventApplicationFlow.find_or_create(event_id: event.id)

      # 参加者情報を取得
      participants = get_participants(event)

      {
        event: {
          id: event.id,
          name: event.name,
          date: event.date,
          deadline: event.deadline,
          place: event.place
        },
        flow: {
          id: flow.id,
          current_step: flow.current_step,
          steps: EventApplicationFlow::STEPS.map do |num, info|
            {
              number: num,
              name: info[:name],
              key: info[:key],
              status: if flow.step_completed?(num)
                       'completed'
                     elsif flow.step_current?(num)
                       'active'
                     else
                       'pending'
                     end
            }
          end,
          application_sent_at: flow.application_sent_at,
          application_method: flow.application_method,
          application_memo: flow.application_memo,
          response_deadline: flow.response_deadline,
          response_deadline_tbd: flow.response_deadline_tbd,
          response_memo: flow.response_memo,
          payment_deadline: flow.payment_deadline,
          payment_bank_info: flow.payment_bank_info,
          payment_completed: flow.payment_completed,
          total_fee: flow.total_fee
        },
        participants: participants,
        editable: @user.admin || @user.permission.include?(:sub_admin)
      }.to_json
    end

    # 参加者情報取得
    get '/participants/:event_id' do
      content_type :json
      event_id = params[:event_id].to_i
      event = Event[event_id]

      halt 404, { error: 'Event not found' }.to_json unless event

      # 権限チェック
      unless @user.admin || @user.permission.include?(:sub_admin)
        user_choice = EventUserChoice.where(user: @user)
          .where(event_choice: event.choices_dataset.where(positive: true))
          .first
        halt 403, { error: 'Forbidden' }.to_json unless user_choice
      end

      participants = get_participants(event)

      { participants: participants }.to_json
    end

    # ステップ進行
    put '/progress/:event_id' do
      content_type :json

      # 管理者のみ
      halt 403, { error: 'Admin only' }.to_json unless @user.admin || @user.permission.include?(:sub_admin)

      event_id = params[:event_id].to_i
      flow = EventApplicationFlow.find_or_create(event_id: event_id)

      action = params[:action] # 'next' or 'skip_to'

      case action
      when 'next'
        flow.advance_step!
      when 'skip_to'
        target_step = params[:target_step].to_i
        flow.skip_to_step!(target_step)
      end

      { success: true, current_step: flow.current_step }.to_json
    end

    # フロー情報更新
    put '/update/:event_id' do
      content_type :json

      # 管理者のみ
      halt 403, { error: 'Admin only' }.to_json unless @user.admin || @user.permission.include?(:sub_admin)

      event_id = params[:event_id].to_i
      flow = EventApplicationFlow.find_or_create(event_id: event_id)

      # 更新可能なフィールド
      allowed_fields = [
        :application_sent_at, :application_method, :application_memo,
        :response_deadline, :response_deadline_tbd, :response_memo,
        :payment_deadline, :payment_bank_info, :payment_completed, :total_fee
      ]

      update_data = params.select { |k, _| allowed_fields.include?(k.to_sym) }
      flow.update(update_data)

      { success: true }.to_json
    end

    # CSV出力
    get '/export_csv/:event_id' do
      # 管理者のみ
      halt 403, 'Admin only' unless @user.admin || @user.permission.include?(:sub_admin)

      event_id = params[:event_id].to_i
      event = Event[event_id]

      halt 404, 'Event not found' unless event

      participants = get_participants(event)

      require 'csv'

      csv_data = CSV.generate(encoding: 'UTF-8', force_quotes: true) do |csv|
        csv << ["\uFEFF" + '氏名（漢字）', '氏名（ふりがな）', '級', '段位', '今年度出場回数']
        participants.each do |p|
          csv << [
            p[:name],
            p[:furigana] || '',
            p[:grade] || '',
            p[:dan] || '',
            p[:yearly_count] || 0
          ]
        end
      end

      content_type 'text/csv; charset=utf-8'
      attachment "application_#{event.name}_#{Date.today}.csv"
      csv_data
    end

    private

    # 参加者情報を取得
    def get_participants(event)
      # 参加するを選択したユーザーを取得
      positive_choices = event.choices_dataset.where(positive: true)
      user_choices = EventUserChoice.where(event_choice: positive_choices).all

      participants = user_choices.map do |uc|
        user = uc.user
        next unless user

        # 今年度の出場回数を計算
        yearly_count = calculate_yearly_count(user, event.date)

        # 申込ステータスを取得または作成
        app_status = EventUserApplicationStatus.find_or_create(event_user_choice_id: uc.id)

        {
          user_id: user.id,
          name: user.name,
          furigana: user.furigana,
          grade: get_user_grade(user),
          dan: get_user_dan(user),
          yearly_count: yearly_count,
          lottery_status: app_status.lottery_status,
          lottery_status_name: app_status.lottery_status_name,
          fee: app_status.fee
        }
      end.compact

      participants
    end

    # 今年度の公認大会出場回数を計算
    def calculate_yearly_count(user, base_date)
      base_date ||= Date.today
      fiscal_year = if base_date.month >= 4
                     base_date.year
                   else
                     base_date.year - 1
                   end

      # 公認大会の個人戦のみカウント
      Event.where(kind: Event.kind__contest, official: true, team_size: 1)
        .where { (date >= Date.new(fiscal_year, 4, 1)) & (date < Date.new(fiscal_year + 1, 4, 1)) }
        .where(Sequel.lit('EXISTS (SELECT 1 FROM event_user_choices euc INNER JOIN event_choices ec ON euc.event_choice_id = ec.id WHERE ec.event_id = events.id AND euc.user_id = ? AND ec.positive = true)', user.id))
        .count
    end

    # ユーザーの級を取得
    def get_user_grade(user)
      grade_attr = UserAttributeKey.first(name: CONF_CONTEST_DEFAULT_AGGREGATE_ATTR)
      return nil unless grade_attr

      user_attr = user.attrs_dataset.where(key: grade_attr).first
      return nil unless user_attr

      user_attr.value.value
    end

    # ユーザーの段位を取得
    def get_user_dan(user)
      dan_attr = UserAttributeKey.first(name: '段位')
      return nil unless dan_attr

      user_attr = user.attrs_dataset.where(key: dan_attr).first
      return nil unless user_attr

      user_attr.value.value
    end
  end
end
