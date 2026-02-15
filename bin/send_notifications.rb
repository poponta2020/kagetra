#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# 通知バッチスクリプト
# cron で毎日 JST 8:00 (UTC 23:00) に実行する
#
# Usage:
#   ruby bin/send_notifications.rb

require_relative '../inits/init'
require_relative '../lib/web_push_sender'

class NotificationBatch
  def initialize
    @today = Date.today
    @now = Time.now
    # 前日の同時刻を基準に「新着」を判定
    @since = @now - 86400
    @sent_count = 0
  end

  def run
    puts "[#{@now}] 通知バッチ開始"

    notify_new_events
    notify_deadline_today
    notify_new_comments
    notify_admin_deadline

    puts "[#{Time.now}] 通知バッチ完了 (送信: #{@sent_count}件)"
  end

  private

  # T-01: 新規大会/行事が追加された
  def notify_new_events
    new_events = Event.where(done: false).where{created_at >= @since}.all
    return if new_events.empty?

    puts "  新規大会/行事: #{new_events.length}件"

    # 通知ONの全購読ユーザーに送信
    users_with_setting(:new_event).each do |user_id|
      new_events.each do |ev|
        date_str = ev.date ? ev.date.strftime("%-m/%-d") : ""
        payload = {
          title: "「#{ev.name}」#{date_str.empty? ? '' : "(#{date_str}) "}案内",
          url: "/top"
        }
        WebPushSender.send_to_user(user_id, payload)
        @sent_count += 1
      end
    end
  end

  # T-02: 締切当日リマインダー
  def notify_deadline_today
    deadline_events = Event.where(done: false, deadline: @today).all
    return if deadline_events.empty?

    puts "  締切当日の大会: #{deadline_events.length}件"

    users_with_setting(:deadline_reminder).each do |user_id|
      user = User[user_id]
      next unless user
      user_attr_values = UserAttributeValue.where(user_attributes: user.attrs_dataset).map(&:id)

      deadline_events.each do |ev|
        # forbidden なユーザーには送らない
        forbidden = (ev.forbidden_attrs & user_attr_values).empty?.!
        next if forbidden

        # 既に登録済みのユーザーには送らない（登録済みなのでリマインダー不要）
        already_chosen = EventChoice.first(event: ev, user_choices: user.event_user_choices)
        next if already_chosen

        payload = {
          title: "「#{ev.name}」の申込締切は本日です",
          url: "/top"
        }
        WebPushSender.send_to_user(user_id, payload)
        @sent_count += 1
      end
    end
  end

  # T-03: コメント新着
  def notify_new_comments
    # 前日以降に投稿されたコメントのあるイベントを検索
    recent_comments = EventComment.where{created_at >= @since}.all
    return if recent_comments.empty?

    # イベントごとにコメント数を集計
    event_comments = {}
    recent_comments.each do |comment|
      event_id = comment.thread_id
      event_comments[event_id] ||= 0
      event_comments[event_id] += 1
    end

    puts "  コメント新着: #{event_comments.length}件のイベント"

    users_with_setting(:event_comment).each do |user_id|
      user = User[user_id]
      next unless user

      event_comments.each do |event_id, count|
        ev = Event[event_id]
        next unless ev

        # そのイベントに登録済みのユーザーにのみ送信
        chosen = EventChoice.first(event: ev, user_choices: user.event_user_choices)
        next unless chosen

        payload = {
          title: "「#{ev.name}」に新しいコメント(#{count}件)",
          url: "/top"
        }
        WebPushSender.send_to_user(user_id, payload)
        @sent_count += 1
      end
    end
  end

  # T-04: [管理者] 締切到来
  def notify_admin_deadline
    # 参加者がいて本日締切を迎えた大会
    deadline_events = Event.where(done: false, deadline: @today)
      .where{participant_count > 0}.all
    return if deadline_events.empty?

    puts "  [管理者] 締切到来: #{deadline_events.length}件"

    admin_users_with_setting(:admin_deadline).each do |user_id|
      deadline_events.each do |ev|
        payload = {
          title: "「#{ev.name}」が締切を迎えました(参加者#{ev.participant_count}名)",
          url: "/top"
        }
        WebPushSender.send_to_user(user_id, payload)
        @sent_count += 1
      end
    end
  end

  # 指定トリガーがONの購読ユーザーIDの一覧
  def users_with_setting(trigger)
    # 購読しているユーザーのうち、該当設定がONのユーザー
    subscribed_user_ids = PushSubscription.select(:user_id).distinct.map(&:user_id)
    return [] if subscribed_user_ids.empty?

    NotificationSetting.where(user_id: subscribed_user_ids, trigger => true)
      .map(&:user_id)
  end

  # 管理者かつ指定トリガーがONの購読ユーザーIDの一覧
  def admin_users_with_setting(trigger)
    admin_ids = User.where(admin: true).or(Sequel.like(:permission, '%sub_admin%'))
      .map(&:id)
    users_with_setting(trigger) & admin_ids
  end
end

NotificationBatch.new.run
