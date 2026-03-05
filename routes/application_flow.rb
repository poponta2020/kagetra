# -*- coding: utf-8 -*-
class MainApp < Sinatra::Base
  namespace '/api/application_flow' do

    # 申込フロー一覧を取得
    get '/list' do
      today = Date.today

      # 締切後かつ参加者がいる大会で、開催日前のものを取得
      base_query = Event.where(kind: Event.kind__contest, done: false)
        .where { (deadline < today) & (date >= today) }
        .where { participant_count > 0 }

      # 一般ユーザーは自分が申し込んだ大会のみ
      events = if @user.admin
        base_query.all
      else
        # 自分が参加選択をした大会のみ
        my_choice_ids = EventUserChoice.where(user: @user)
          .select(:event_choice_id)
        my_event_ids = EventChoice.where(id: my_choice_ids, positive: true)
          .select(:event_id)
        base_query.where(id: my_event_ids).all
      end

      # 各大会の申込フロー情報を取得
      events.map do |ev|
        flow = EventApplicationFlow.first(event: ev) || create_flow_if_needed(ev)

        {
          event_id: ev.id,
          event_name: ev.name,
          event_date: ev.date,
          deadline: ev.deadline,
          participant_count: ev.participant_count,
          current_step: flow&.current_step || 1,
          step_name: flow&.step_name || "会内締切",
          next_action: flow&.current_action || "参加者を確認し、申込書を作成してください"
        }
      end
    end

    # 申込フロー詳細を取得
    get '/detail/:event_id' do
      ev = Event[params[:event_id].to_i]
      halt 404 if ev.nil?

      # 権限チェック: 管理者または申込者のみ
      unless @user.admin
        my_choice = EventUserChoice.first(
          user: @user,
          event_choice: ev.choices_dataset.where(positive: true)
        )
        halt 403 if my_choice.nil?
      end

      flow = EventApplicationFlow.first(event: ev) || create_flow_if_needed(ev)

      # 基本情報
      result = {
        event_id: ev.id,
        event_name: ev.name,
        event_formal_name: ev.formal_name,
        event_date: ev.date,
        deadline: ev.deadline,
        place: ev.place,
        description: ev.description,
        participant_count: ev.participant_count,

        # フロー情報
        current_step: flow.current_step,
        step_name: flow.step_name,
        steps: EventApplicationFlow::STEPS.map do |num, info|
          {
            number: num,
            name: info[:name],
            active_form: info[:active_form],
            completed: flow.current_step > num,
            current: flow.current_step == num,
            enabled: flow.step_enabled?(num)
          }
        end,
        current_action: flow.current_action,
        next_action: flow.current_action,

        # 詳細情報
        has_lottery: flow.has_lottery,
        payment_method: flow.payment_method,
        application_sent_at: flow.application_sent_at,
        response_received_at: flow.response_received_at,
        payment_deadline: flow.payment_deadline,
        payment_destination: flow.payment_destination,
        total_fee: flow.total_fee,
        payment_completed_at: flow.payment_completed_at,
        memo: flow.memo,

        is_admin: @user.admin
      }

      result
    end

    # 参加者情報を取得（申込書作成用）
    get '/participants/:event_id' do
      ev = Event[params[:event_id].to_i]
      halt 404 if ev.nil?
      halt 403 unless @user.admin # 管理者のみ

      # 参加者一覧を取得
      participants = get_participants_for_application(ev)

      participants
    end

    # CSV出力
    get '/export_csv/:event_id' do
      ev = Event[params[:event_id].to_i]
      halt 404 if ev.nil?
      halt 403 unless @user.admin # 管理者のみ

      participants = get_participants_for_application(ev)

      # CSVヘッダー
      csv_data = "\uFEFF" # UTF-8 BOM
      csv_data += "名前,ふりがな,級,段位,今年度公認大会出場回数\n"

      participants.each do |p|
        csv_data += "#{p[:name]},#{p[:furigana]},#{p[:grade]},#{p[:dan]},#{p[:participation_count]}\n"
      end

      content_type 'text/csv; charset=utf-8'
      attachment "#{ev.name}_参加者一覧.csv"
      csv_data
    end

    # フロー進行（次のステップに進む）
    put '/progress/:event_id' do
      ev = Event[params[:event_id].to_i]
      halt 404 if ev.nil?
      halt 403 unless @user.admin # 管理者のみ

      flow = EventApplicationFlow.first(event: ev) || create_flow_if_needed(ev)

      flow.proceed_to_next_step

      {success: true, current_step: flow.current_step, step_name: flow.step_name}
    end

    # フロー戻し（前のステップに戻る）
    put '/regress/:event_id' do
      ev = Event[params[:event_id].to_i]
      halt 404 if ev.nil?
      halt 403 unless @user.admin # 管理者のみ

      flow = EventApplicationFlow.first(event: ev) || create_flow_if_needed(ev)

      flow.regress_to_previous_step

      {success: true, current_step: flow.current_step, step_name: flow.step_name}
    end

    # フロー情報更新
    put '/update/:event_id' do
      ev = Event[params[:event_id].to_i]
      halt 404 if ev.nil?
      halt 403 unless @user.admin # 管理者のみ

      flow = EventApplicationFlow.first(event: ev) || create_flow_if_needed(ev)

      # 更新可能フィールド
      update_params = {}
      [:has_lottery, :payment_method, :application_sent_at, :application_method,
       :response_received_at, :response_memo, :lottery_result_date,
       :payment_deadline, :payment_destination, :total_fee, :payment_completed_at, :memo].each do |key|
        update_params[key] = params[key.to_s] if params.has_key?(key.to_s)
      end

      flow.update(update_params)

      {success: true}
    end

    private

    # フローが存在しない場合は作成
    def create_flow_if_needed(event)
      EventApplicationFlow.find_or_create(event_id: event.id) do
        EventApplicationFlow.new(
          event_id: event.id,
          current_step: 1,
          has_lottery: false,
          payment_method: 'advance'
        )
      end
    end

    # 申込書作成用の参加者情報を取得
    def get_participants_for_application(event)
      # 今年度の開始日（4月1日）
      fiscal_year_start = if event.date.month >= 4
        Date.new(event.date.year, 4, 1)
      else
        Date.new(event.date.year - 1, 4, 1)
      end

      # 参加者の選択を取得
      positive_choices = event.choices_dataset.where(positive: true)
      user_choices = EventUserChoice.where(event_choice: positive_choices, cancel: false).all

      user_choices.map do |uc|
        user = uc.user
        next nil if user.nil?

        # ふりがなを名簿から取得
        addrbook = AddrbookItem.first(user: user)
        furigana = addrbook&.attr('ふりがな') || ""

        # 級を取得
        grade_attr = UserAttributeKey.first(name: '級')
        grade_value = if grade_attr
          user_attr = UserAttribute.first(user: user, attr_key: grade_attr)
          user_attr&.attr_value&.value || ""
        else
          ""
        end

        # 段位を取得
        dan_attr = UserAttributeKey.first(name: '段位')
        dan_value = if dan_attr
          user_attr = UserAttribute.first(user: user, attr_key: dan_attr)
          user_attr&.attr_value&.value || ""
        else
          ""
        end

        # 今年度の公認大会出場回数を計算
        participation_count = Event.where(kind: Event.kind__contest, official: true, done: true)
          .where { (date >= fiscal_year_start) & (date < event.date) }
          .where(
            id: EventUserChoice.where(user: user)
              .select(:event_choice_id)
              .join(:event_choices, id: :event_choice_id)
              .where(positive: true)
              .select(:event_id)
          ).count

        {
          user_id: user.id,
          name: user.name,
          furigana: furigana,
          grade: grade_value,
          dan: dan_value,
          participation_count: participation_count
        }
      end.compact.sort_by { |p| [p[:grade], p[:name]] }
    end
  end
end
