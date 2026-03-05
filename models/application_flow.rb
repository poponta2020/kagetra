# -*- coding: utf-8 -*-
# 申込フロー管理
class EventApplicationFlow < Sequel::Model(:event_application_flows)
  many_to_one :event

  # ステップ定義
  STEPS = {
    1 => {name: "会内締切", active_form: "会内締切確認中"},
    2 => {name: "大会申込", active_form: "大会申込中"},
    3 => {name: "返信待ち", active_form: "返信待ち"},
    4 => {name: "抽選結果待ち", active_form: "抽選結果待ち"},
    5 => {name: "参加費支払い", active_form: "参加費支払い中"},
    6 => {name: "完了", active_form: "完了"}
  }

  def step_name
    STEPS[current_step][:name]
  end

  def step_active_form
    STEPS[current_step][:active_form]
  end

  # 次のステップに進む
  def proceed_to_next_step
    if current_step < 6
      self.current_step += 1
      save
    end
  end

  # 前のステップに戻る
  def regress_to_previous_step
    if current_step > 1
      self.current_step -= 1
      save
    end
  end

  # 現在のステップで必要なアクション
  def current_action
    case current_step
    when 1
      "参加者を確認し、申込書を作成してください"
    when 2
      "申込書を主催者に送付してください"
    when 3
      "主催者からの返信を待っています"
    when 4
      "抽選結果の確認を待っています"
    when 5
      "参加費を確認し、主催者に支払ってください"
    when 6
      "大会当日をお待ちください"
    else
      ""
    end
  end

  # ステップが有効かどうか（スキップ判定）
  def step_enabled?(step_num)
    case step_num
    when 4
      has_lottery # 抽選あり大会のみ
    when 5
      payment_method == 'advance' # 事前振込のみ
    else
      true
    end
  end
end

# 参加者ごとの申込状況
class EventUserApplicationStatus < Sequel::Model(:event_user_application_statuses)
  many_to_one :event_user_choice

  # 抽選状態の定義
  LOTTERY_STATUSES = {
    'pending' => '抽選前',
    'won' => '当選',
    'lost' => '落選',
    'waiting' => 'キャンセル待ち'
  }

  def lottery_status_label
    LOTTERY_STATUSES[lottery_status] || lottery_status
  end

  # 参加費集金状況
  def fee_collected?
    !fee_collected_at.nil?
  end
end
