# -*- coding: utf-8 -*-
Sequel.migration do
  up do
    # 申込フロー管理テーブル
    create_table(:event_application_flows) do
      primary_key :id
      foreign_key :event_id, :events, null: false, unique: true

      Integer :current_step, null: false, default: 1  # 1〜6

      # ステップ2: 大会申込
      Date :application_sent_at                       # 送付日
      String :application_method                      # 'email', 'mail', 'web'
      Text :application_memo                          # メモ

      # ステップ3: 返信待ち
      Date :response_deadline                         # 返信期限
      TrueClass :response_deadline_tbd, default: false # 未定フラグ
      Text :response_memo                             # 受理番号等

      # ステップ5: 参加費支払い
      Date :payment_deadline                          # 支払期限
      Text :payment_bank_info                         # 振込先
      TrueClass :payment_completed, default: false    # 支払済み
      Integer :total_fee                              # 合計参加費（円）

      DateTime :created_at
      DateTime :updated_at

      index :event_id
    end

    # 参加者ごとの状態管理テーブル
    create_table(:event_user_application_statuses) do
      primary_key :id
      foreign_key :event_user_choice_id, :event_user_choices, null: false, unique: true

      # ステップ4: 抽選結果
      String :lottery_status                          # 'pending', 'won', 'lost', 'waiting'

      # ステップ5: 参加費
      Integer :fee                                    # 個人の参加費（円）
      TrueClass :fee_paid_to_organizer, default: false # 会→主催者への支払済み
      TrueClass :fee_collected_from_user, default: false # 個人→会への集金済み

      DateTime :created_at
      DateTime :updated_at

      index :event_user_choice_id
    end
  end

  down do
    drop_table(:event_user_application_statuses)
    drop_table(:event_application_flows)
  end
end
