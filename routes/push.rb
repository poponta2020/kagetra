# -*- coding: utf-8 -*-
class MainApp < Sinatra::Base
  namespace '/api/push' do
    # VAPID 公開鍵の取得
    get '/vapid_public_key' do
      {vapid_public_key: CONF_VAPID_PUBLIC_KEY}
    end

    # 購読登録
    post '/subscribe' do
      sub = @json["subscription"]
      halt 400, {error: "subscription is required"}.to_json unless sub
      endpoint = sub["endpoint"]
      p256dh = sub["keys"]["p256dh"]
      auth = sub["keys"]["auth"]
      halt 400, {error: "invalid subscription"}.to_json unless endpoint && p256dh && auth

      existing = PushSubscription.first(endpoint: endpoint)
      if existing
        existing.update(
          user_id: @user.id,
          p256dh: p256dh,
          auth: auth,
          user_agent: request.user_agent
        )
      else
        PushSubscription.create(
          user_id: @user.id,
          endpoint: endpoint,
          p256dh: p256dh,
          auth: auth,
          user_agent: request.user_agent
        )
      end

      # 通知設定がなければデフォルトで作成
      NotificationSetting.find_or_create(user_id: @user.id)

      {ok: true}
    end

    # 購読解除
    delete '/subscribe' do
      endpoint = @json["endpoint"]
      halt 400, {error: "endpoint is required"}.to_json unless endpoint
      PushSubscription.where(endpoint: endpoint, user_id: @user.id).delete
      {ok: true}
    end

    # 通知設定の取得
    get '/settings' do
      setting = NotificationSetting.find_or_create(user_id: @user.id)
      {
        new_event: setting.new_event,
        deadline_reminder: setting.deadline_reminder,
        event_comment: setting.event_comment,
        admin_deadline: setting.admin_deadline
      }
    end

    # 通知設定の更新
    put '/settings' do
      setting = NotificationSetting.find_or_create(user_id: @user.id)
      cols = {}
      [:new_event, :deadline_reminder, :event_comment, :admin_deadline].each do |key|
        cols[key] = !!@json[key.to_s] if @json.has_key?(key.to_s)
      end
      setting.update(cols) unless cols.empty?
      {ok: true}
    end
  end
end
