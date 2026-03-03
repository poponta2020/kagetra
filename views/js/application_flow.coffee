define (require, exports, module) ->

  # 申込フロー一覧モデル
  FlowListCollection = Backbone.Collection.extend
    url: 'api/application_flow/list'

  # 申込フロー一覧ビュー
  FlowListView = Backbone.View.extend
    el: '#application-flow-list'
    template: _.template($('#templ-flow-list').html())
    events:
      'click .show-detail': 'show_detail'

    initialize: ->
      _.bindAll(this, 'render')
      @collection = new FlowListCollection()
      @collection.fetch().done(@render)

    render: ->
      @$el.html(@template(data: @collection.toJSON()))

    show_detail: (ev) ->
      ev.preventDefault()
      event_id = $(ev.currentTarget).closest('.flow-list-item').data('id')
      window.flow_detail_view = new FlowDetailView(event_id: event_id)
      false

  # 申込フロー詳細モデル
  FlowDetailModel = Backbone.Model.extend
    urlRoot: 'api/application_flow/detail'

  # 参加者一覧モデル
  ParticipantsCollection = Backbone.Collection.extend
    initialize: (models, options) ->
      @event_id = options.event_id
    url: ->
      "api/application_flow/participants/#{@event_id}"

  # 申込フロー詳細ビュー
  FlowDetailView = Backbone.View.extend
    el: '#container-flow-detail'
    template: _.template($('#templ-flow-detail').html())
    template_participants: _.template($('#templ-participants').html())
    events:
      'click .back-to-list': 'back_to_list'
      'click .show-participants': 'show_participants'
      'click .export-csv': 'export_csv'
      'click .proceed-step': 'proceed_step'

    initialize: (options) ->
      _.bindAll(this, 'render')
      @event_id = options.event_id
      @model = new FlowDetailModel(id: @event_id)
      @model.fetch().done(@render)

    render: ->
      $('#flow-detail-content').html(@template(data: @model.toJSON()))
      @$el.foundation('reveal', 'open')

    back_to_list: (ev) ->
      ev.preventDefault()
      @$el.foundation('reveal', 'close')
      window.flow_list_view.collection.fetch().done(window.flow_list_view.render)
      false

    show_participants: (ev) ->
      ev.preventDefault()
      @participants = new ParticipantsCollection([], event_id: @event_id)
      that = this
      @participants.fetch().done ->
        $('#participants-container').html(that.template_participants(data: that.participants.toJSON()))
      false

    export_csv: (ev) ->
      ev.preventDefault()
      window.location.href = "api/application_flow/export_csv/#{@event_id}"
      false

    proceed_step: (ev) ->
      ev.preventDefault()
      return unless confirm('次のステップに進みますか？')

      that = this
      $.ajax
        url: "api/application_flow/progress/#{@event_id}"
        type: 'PUT'
        dataType: 'json'
        success: (data) ->
          alert("#{data.step_name}に進みました")
          that.model.fetch().done(that.render)
        error: (xhr) ->
          alert('エラーが発生しました')
      false

  # 初期化
  init: ->
    $(document).foundation()
    window.flow_list_view = new FlowListView()

  exports.init = init
