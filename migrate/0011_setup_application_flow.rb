# -*- coding: utf-8 -*-
require_relative './helper'
Sequel.migration do
  change do

    # 申込フロー管理テーブル
    create_table_custom(:event_application_flows, [:base], comment:"大会申込フロー管理") do
      foreign_key :event_id, :events, null: false, unique: true, on_delete: :cascade, comment:"対象大会"
      Integer :current_step, null: false, default: 1, comment:"現在のステップ(1:会内締切,2:大会申込,3:返信待ち,4:抽選結果待ち,5:参加費支払い,6:完了)"
      TrueClass :has_lottery, default: false, comment:"抽選あり"
      String :payment_method, default: 'advance', comment:"支払方法(advance:事前振込,onsite:現地払い)"

      # ステップ2: 大会申込
      Date :application_sent_at, comment:"申込書送付日"
      String :application_method, size:20, comment:"送付方法(email,mail,web)"

      # ステップ3: 返信待ち
      Date :response_received_at, comment:"主催者返信受領日"
      Text :response_memo, comment:"受理番号や返信内容のメモ"

      # ステップ4: 抽選結果待ち
      Date :lottery_result_date, comment:"抽選結果判明日"

      # ステップ5: 参加費支払い
      Date :payment_deadline, comment:"支払期限"
      String :payment_destination, size:255, comment:"振込先情報"
      Integer :total_fee, comment:"合計参加費(円)"
      Date :payment_completed_at, comment:"主催者への支払完了日"

      # 共通
      Text :memo, comment:"メモ欄"
    end

    # 参加者ごとの申込状況管理テーブル
    create_table_custom(:event_user_application_statuses, [:base], comment:"参加者ごとの申込状況") do
      foreign_key :event_user_choice_id, :event_user_choices, null: false, unique: true, on_delete: :cascade, comment:"参加選択"
      String :lottery_status, size:20, default: 'pending', comment:"抽選状況(pending:抽選前,won:当選,lost:落選,waiting:キャンセル待ち)"
      Integer :fee, comment:"個人の参加費(円)"
      Date :fee_collected_at, comment:"個人から会への参加費集金完了日"
      Text :memo, comment:"個人ごとのメモ"
    end

  end
end
