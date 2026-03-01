define (require,exports,module) ->
  $rc = require("result_common")
  ResultListRouter = Backbone.Router.extend
    routes:
      "year/:year" : "do_year"
      "": -> @navigate("year/#{(new Date()).getFullYear()}",{trigger:true,replace:true})
    do_year: (year) ->
      window.result_list_view?.remove()
      window.result_list_view = new ResultListView(year:year)
  ResultListModel = Backbone.Model.extend
    url: -> "api/result_list/year/#{@get('year')}"
  ResultListView = Backbone.View.extend
    template: _.template_braces($("#templ-result-list").html())
    events:
      "click .page" : "do_page"
      "change .toggle-empty" : "do_toggle_empty"
    do_page: (ev)->
      year = $(ev.currentTarget).data("year")
      window.result_list_router.navigate("year/#{year}",{trigger:true})
      false
    do_toggle_empty: (ev)->
      @hide_empty = !$(ev.currentTarget).prop("checked")
      @render()
    initialize: ->
      @hide_empty = true
      @model = new ResultListModel(year:@options.year)
      @listenTo(@model,"sync",@render)
      @model.fetch()
    render: ->
      data = @model.toJSON()
      if @hide_empty
        data.list = _.filter(data.list, (x) -> x.user_count > 0)
      @$el.html(@template(data:data))
      @$el.find(".toggle-empty").prop("checked", !@hide_empty)
      @$el.appendTo("#result-list")
  init: ->
    $rc.init()
    window.result_list_router = new ResultListRouter()
    Backbone.history.start()
