# -*- coding: utf-8 -*-

# 申込フロー管理
class EventApplicationFlow < Sequel::Model(:event_application_flows)
  many_to_one :event

  # ステップ定義
  STEPS = {
    1 => { name: '会内締切', key: 'internal_deadline' },
    2 => { name: '大会申込', key: 'application' },
    3 => { name: '返信待ち', key: 'response_waiting' },
    4 => { name: '抽選結果待ち', key: 'lottery_waiting' },
    5 => { name: '参加費支払い', key: 'payment' },
    6 => { name: '完了', key: 'completed' }
  }

  def before_create
    super
    self.current_step ||= 1
    self.created_at = Time.now
    self.updated_at = Time.now
  end

  def before_update
    super
    self.updated_at = Time.now
  end

  # 現在のステップ名を取得
  def current_step_name
    STEPS[self.current_step][:name]
  end

  # 現在のステップキーを取得
  def current_step_key
    STEPS[self.current_step][:key]
  end

  # 次のステップへ進む
  def advance_step!
    if self.current_step < 6
      self.current_step += 1
      self.save
    end
  end

  # 指定ステップへスキップ
  def skip_to_step!(step_number)
    if step_number.between?(1, 6)
      self.current_step = step_number
      self.save
    end
  end

  # ステップが完了しているか
  def step_completed?(step_number)
    self.current_step > step_number
  end

  # ステップが現在進行中か
  def step_current?(step_number)
    self.current_step == step_number
  end

  # ステップが未完了か
  def step_pending?(step_number)
    self.current_step < step_number
  end
end

# 参加者ごとの申込状態管理
class EventUserApplicationStatus < Sequel::Model(:event_user_application_statuses)
  many_to_one :event_user_choice

  # 抽選ステータス定義
  LOTTERY_STATUSES = {
    'pending' => '結果待ち',
    'won' => '当選',
    'lost' => '落選',
    'waiting' => 'キャンセル待ち'
  }

  def before_create
    super
    self.lottery_status ||= 'pending'
    self.created_at = Time.now
    self.updated_at = Time.now
  end

  def before_update
    super
    self.updated_at = Time.now
  end

  # 抽選ステータスの日本語名
  def lottery_status_name
    LOTTERY_STATUSES[self.lottery_status] || self.lottery_status
  end

  # 当選しているか
  def won?
    self.lottery_status == 'won'
  end

  # 落選しているか
  def lost?
    self.lottery_status == 'lost'
  end

  # キャンセル待ちか
  def waiting?
    self.lottery_status == 'waiting'
  end
end
