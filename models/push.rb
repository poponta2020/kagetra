# -*- coding: utf-8 -*-

class PushSubscription < Sequel::Model(:push_subscriptions)
  many_to_one :user
end

class NotificationSetting < Sequel::Model(:notification_settings)
  many_to_one :user
end
