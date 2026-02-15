define ["crypto-hmac", "crypto-base64", "crypto-pbkdf2"], ->
  UserConfModel = Backbone.Model.extend
    url: "api/user_conf/etc"
  UserConfView = Backbone.View.extend
    el: "#user-conf"
    template:  _.template_braces($("#templ-user-conf").html())
    events:
      "submit .form" : "do_submit"
    do_submit: ->
      @model.set(@$el.find('.form').serializeObj())
      @model.save().done(_.with_error("更新しました"))
      false
    initialize: ->
      _.bindAll(this,"render","do_submit")
      @model = new UserConfModel()
      @listenTo(@model,"sync",@render)
      @model.fetch()
    render: ->
      @$el.html(@template(@model.toJSON()))

  ChangePassView = Backbone.View.extend
    el: "#change-pass"
    template:  _.template($("#templ-change-pass").html())
    events:
      "submit .form" : "do_submit"
    do_submit: ->
      _.confirm_change_password
        el: @$el
        cur: ".pass-cur"
        new_1: ".pass-new"
        new_2: ".pass-retype"
        url_confirm: 'api/user/confirm_password'
        url_change: 'api/user/change_password'
        url_salt: 'api/user/mysalt'

    initialize: ->
      _.bindAll(this,"do_submit")
      @render()
    render: ->
      @$el.html(@template())

  # VAPID公開鍵をUint8Arrayに変換
  urlBase64ToUint8Array = (base64String) ->
    padding = '='.repeat((4 - base64String.length % 4) % 4)
    base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/')
    rawData = window.atob(base64)
    outputArray = new Uint8Array(rawData.length)
    for i in [0...rawData.length]
      outputArray[i] = rawData.charCodeAt(i)
    outputArray

  NotificationSettingsView = Backbone.View.extend
    el: "#notification-settings"
    template: _.template($("#templ-notification-settings").html())
    events:
      "click .btn-subscribe": "do_subscribe"
      "click .btn-unsubscribe": "do_unsubscribe"
      "click .btn-save-settings": "do_save_settings"
    initialize: ->
      _.bindAll(this, "render", "do_subscribe", "do_unsubscribe", "do_save_settings")
      @push_supported = 'serviceWorker' of navigator and 'PushManager' of window
      @push_subscribed = false
      @settings = {}
      @vapid_public_key = null
      if @push_supported
        @check_subscription()
      else
        @render()
    check_subscription: ->
      self = this
      # VAPID公開鍵を取得
      $.getJSON("api/push/vapid_public_key").done (data) ->
        self.vapid_public_key = data.vapid_public_key
        navigator.serviceWorker.ready.then (reg) ->
          reg.pushManager.getSubscription().then (sub) ->
            self.push_subscribed = sub?
            if self.push_subscribed
              $.getJSON("api/push/settings").done (settings) ->
                self.settings = settings
                self.render()
            else
              self.render()
    render: ->
      data =
        push_supported: @push_supported
        push_subscribed: @push_subscribed
        is_admin: window.g_is_admin
        new_event: if @settings.new_event? then @settings.new_event else true
        deadline_reminder: if @settings.deadline_reminder? then @settings.deadline_reminder else true
        event_comment: if @settings.event_comment? then @settings.event_comment else true
        admin_deadline: if @settings.admin_deadline? then @settings.admin_deadline else true
      @$el.html(@template(data))
    do_subscribe: ->
      self = this
      return unless @vapid_public_key
      navigator.serviceWorker.ready.then (reg) ->
        reg.pushManager.subscribe(
          userVisibleOnly: true
          applicationServerKey: urlBase64ToUint8Array(self.vapid_public_key)
        ).then((sub) ->
          # サーバーに購読情報を送信
          $.ajax
            url: "api/push/subscribe"
            type: "POST"
            contentType: "application/json"
            data: JSON.stringify(subscription: sub.toJSON())
          .done ->
            self.push_subscribed = true
            # 設定を取得してから再描画
            $.getJSON("api/push/settings").done (settings) ->
              self.settings = settings
              self.render()
              _.cb_alert("通知を有効にしました")
        ).catch (err) ->
          if Notification.permission == 'denied'
            _.cb_alert("通知がブロックされています。ブラウザの設定から通知を許可してください。")
          else
            _.cb_alert("通知の有効化に失敗しました: " + err.message)
    do_unsubscribe: ->
      self = this
      navigator.serviceWorker.ready.then (reg) ->
        reg.pushManager.getSubscription().then (sub) ->
          return unless sub
          endpoint = sub.endpoint
          sub.unsubscribe().then ->
            $.ajax
              url: "api/push/subscribe"
              type: "DELETE"
              contentType: "application/json"
              data: JSON.stringify(endpoint: endpoint)
            .done ->
              self.push_subscribed = false
              self.settings = {}
              self.render()
              _.cb_alert("通知を無効にしました")
    do_save_settings: ->
      form = @$el.find('.notification-form')
      data =
        new_event: form.find('[name=new_event]').is(':checked')
        deadline_reminder: form.find('[name=deadline_reminder]').is(':checked')
        event_comment: form.find('[name=event_comment]').is(':checked')
        admin_deadline: form.find('[name=admin_deadline]').is(':checked')
      $.ajax
        url: "api/push/settings"
        type: "PUT"
        contentType: "application/json"
        data: JSON.stringify(data)
      .done ->
        _.cb_alert("設定を保存しました")

  init: ->
    window.change_pass_view = new ChangePassView()
    window.user_conf_view = new UserConfView()
    window.notification_settings_view = new NotificationSettingsView()
