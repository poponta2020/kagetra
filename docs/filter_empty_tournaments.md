# 大会一覧画面：参加者なし大会のフィルタリング機能

## 概要

大会一覧画面（`/result_list`）に、会からの参加者がいなかった大会（`participant_count == 0`）を表示/非表示に切り替えるトグル機能を追加する。

## 現状の仕様

- 大会結果ページ（`/result`）の `recent_contests` では、既に `participant_count > 0` でフィルタされている（`routes/result.rb:47`）
- `result.coffee:617` に「※出場者のいない大会は『大会一覧』にのみ表示されます．」とあり、現状は大会一覧だけが参加者なし大会を含む
- `participant_count` は大会完了後、`ContestUser`（出場者レコード）の件数で更新される（`models/result.rb:40-43`）

## 改修対象ファイル

### 1. routes/result_misc.rb（209-226行目）

APIエンドポイント `/api/result_list/year/:year`

```ruby
# 現状のコード
get '/api/result_list/year/:year' do
  year = params[:year].to_i
  minyear = Event.where(kind:Event.kind__contest).min(:date).year
  sday = Date.new(year,1,1)
  eday = Date.new(year+1,1,1)
  list = Event.where{ (date >= sday) & (date < eday)}
              .where(done:true,kind:Event.kind__contest)
              .order(Sequel.desc(:date))
              .map{|x|
                r = result_summary(x)
                if @public_mode and r[:prizes].empty? then
                  nil
                else
                  r
                end
              }.compact
  {list:list,minyear:minyear,maxyear:Date.today.year,curyear:year}
end
```

改修内容: フィルタパラメータ（例: `hide_empty=true`）を受け取り、`participant_count > 0` で絞り込めるようにする。

### 2. views/result_list.haml（11-25行目）

大会一覧のテンプレート。

改修内容: トグルUI（チェックボックス等）を追加。「参加者なしの大会を表示する」切り替えボタン。

### 3. views/js/result_list.coffee

大会一覧のフロントエンドロジック。

改修内容: トグル操作時にフィルタリングを行う処理を追加。

## 参考ファイル（直接改修は不要）

| ファイル | 参考箇所 |
|---------|---------|
| `routes/result.rb:47` | `recent_contests` で `.where{participant_count > 0}` フィルタの実装例 |
| `views/event_detail.haml:276-296` | `#templ-result-summaries` テンプレート（result_listと共有） |
| `models/result.rb:40-43` | `ContestUser#update_participant_count` の実装 |
| `models/event.rb:107-120` | `EventUserChoice` による `participant_count` 更新 |

## 実装方針

### 方針A: サーバーサイドフィルタ

APIにクエリパラメータを追加し、サーバー側で `participant_count > 0` 条件を付ける。

- メリット: データ転送量が減る。大量データに強い
- デメリット: トグル切替時にAPI再呼出しが必要

```ruby
# イメージ
query = Event.where{ (date >= sday) & (date < eday)}
             .where(done:true, kind:Event.kind__contest)
if params[:hide_empty] == "true"
  query = query.where{participant_count > 0}
end
```

### 方針B: クライアントサイドフィルタ

APIは現状のまま全大会を返し、CoffeeScript側で `user_count > 0` のものだけ表示する。

- メリット: API変更不要。トグル切替が即座に反映される（通信不要）
- デメリット: 全データを常に取得する

```coffeescript
# イメージ
render: ->
  data = @model.toJSON()
  if @hide_empty
    data.list = _.filter(data.list, (x) -> x.user_count > 0)
  @$el.html(@template(data: data))
```

### 検討事項

- トグルのデフォルト値: 初期状態で参加者なし大会を「非表示」にするか「表示」にするか
- 年単位のデータ量であれば方針Bで十分と思われる
