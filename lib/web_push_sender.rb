# -*- coding: utf-8 -*-
require 'web-push'

module WebPushSender
  def self.send_notification(subscription, payload)
    WebPush.payload_send(
      message: payload.to_json,
      endpoint: subscription.endpoint,
      p256dh: subscription.p256dh,
      auth: subscription.auth,
      vapid: {
        subject: CONF_VAPID_SUBJECT,
        public_key: CONF_VAPID_PUBLIC_KEY,
        private_key: CONF_VAPID_PRIVATE_KEY
      },
      ttl: 86400
    )
  end

  # ユーザーの全端末に通知を送信。無効な購読は自動削除する。
  def self.send_to_user(user_id, payload)
    subscriptions = PushSubscription.where(user_id: user_id).all
    subscriptions.each do |sub|
      begin
        send_notification(sub, payload)
      rescue WebPush::ExpiredSubscription
        sub.delete
      rescue WebPush::InvalidSubscription
        sub.delete
      rescue => e
        $stderr.puts "Push送信エラー (user_id=#{user_id}, endpoint=#{sub.endpoint[0..50]}): #{e.message}"
      end
    end
  end
end
