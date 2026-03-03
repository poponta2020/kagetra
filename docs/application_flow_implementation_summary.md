# 申込フロー管理機能 実装完了サマリー

> 実装日: 2026-03-03
> ステータス: **Phase 1 MVP 実装完了・デプロイ済み ✅**
> 要件定義書: [application_flow_requirements_v1.md](./application_flow_requirements_v1.md)

---

## ✅ デプロイ完了

**実施日時:** 2026-03-03 12:45 JST

**デプロイ環境:**
- Docker Compose環境
- アプリケーション: http://localhost:9292
- データベース: PostgreSQL 9.6 (localhost:5433)

**実施内容:**
1. ✅ Dockerコンテナ起動完了
2. ✅ データベースマイグレーション実行（v10 → v11）
3. ✅ テーブル作成確認
   - `event_application_flows` テーブル作成済み
   - `event_user_application_statuses` テーブル作成済み
4. ✅ アプリケーション起動確認（WEBrick on port 9292）

**動作確認項目:**
- [ ] ログイン後、トップバーに「申込管理」メニューが表示される
- [ ] 申込管理画面が開く
- [ ] 締切後・参加者ありの大会が一覧に表示される（データがある場合）
- [ ] 大会詳細画面が開く
- [ ] フローチャートが正しく表示される
- [ ] CSV出力が動作する

---

## 実装内容

Phase 1 MVP（基本的な申込フロー一覧・詳細画面）の実装を完了しました。

### 実装されたファイル

#### 1. データベースマイグレーション

- **migrate/0011_setup_application_flow.rb**
  - `event_application_flows` テーブル作成
  - `event_user_application_statuses` テーブル作成
  - 6ステップのフロー管理に必要な全カラムを定義

#### 2. モデル

- **models/application_flow.rb**
  - `EventApplicationFlow` モデル: 大会ごとのフロー管理
  - `EventUserApplicationStatus` モデル: 参加者ごとの状況管理
  - ステップ定義、進行ロジック、スキップ判定を実装

- **models/init.rb**
  - application_flow モデルを require に追加

#### 3. バックエンドAPI

- **routes/application_flow.rb**
  - `GET /api/application_flow/list` - フロー一覧取得
  - `GET /api/application_flow/detail/:event_id` - フロー詳細取得
  - `GET /api/application_flow/participants/:event_id` - 参加者情報取得
  - `GET /api/application_flow/export_csv/:event_id` - CSV出力
  - `PUT /api/application_flow/progress/:event_id` - 次ステップへ進行
  - `PUT /api/application_flow/update/:event_id` - フロー情報更新

- **routes/init.rb**
  - application_flow ルートを require に追加

- **routes/misc.rb**
  - `GET /application_flow` ページルートを追加

#### 4. フロントエンド

- **views/application_flow.haml**
  - 申込管理画面のメインテンプレート
  - フロー一覧テンプレート
  - フロー詳細テンプレート（モーダル表示）
  - 参加者一覧テンプレート

- **views/js/application_flow.coffee**
  - Backbone.js ベースのフロントエンドロジック
  - FlowListView: 一覧表示
  - FlowDetailView: 詳細表示・操作
  - ParticipantsCollection: 参加者データ管理

- **views/sass/application_flow.scss**
  - 申込管理画面専用スタイル
  - 横向きフローチャート（Flexbox使用）
  - ステップの状態別スタイル（完了/進行中/未完了）

#### 5. 設定ファイル

- **conf.docker.rb**
  - トップバーメニューに「申込管理」を追加
  - `CONF_DEFAULT_CONTEST_FEES` を追加（級別デフォルト参加費）

- **conf.rb.sample**
  - 同上（本番環境用）

---

## デプロイ手順

### 1. データベースマイグレーション実行

Docker環境の場合:

```bash
# Dockerコンテナを起動
docker-compose up -d

# マイグレーション実行
docker-compose exec web bundle exec ruby -r ./inits/init.rb -e "Sequel.extension :migration; Sequel::Migrator.run(DB, 'migrate', target: 11)"
```

本番環境の場合:

```bash
bundle exec ruby -r ./inits/init.rb -e "Sequel.extension :migration; Sequel::Migrator.run(DB, 'migrate', target: 11)"
```

### 2. リソースバージョンの更新

`inits/init.rb` の `G_RESOURCE_VERSION` をインクリメントしてください。
（CSSとJavaScriptのキャッシュをクリアするため）

### 3. アプリケーション再起動

Docker環境:
```bash
docker-compose restart web
```

本番環境:
```bash
./scripts/unicorn_ctl.sh restart
```

---

## 機能概要

### 管理者向け機能

1. **申込フロー一覧**
   - 締切後・参加者ありの大会を表示
   - 現在のステップと次のアクションを一覧表示

2. **申込フロー詳細**
   - 横向きフローチャートで進捗を可視化
   - 現在のタスクを強調表示
   - 申込書作成用データ表示・CSV出力
   - 次のステップへの進行ボタン

3. **参加者情報管理**
   - 名前、ふりがな、級、段位
   - 今年度の公認大会出場回数（自動計算）

### 一般ユーザー向け機能

- 自分が申し込んだ大会のフロー状況を閲覧
- 現在のステップと次のアクションを確認

---

## フロー定義

| ステップ | 名称 | 説明 |
|---------|------|------|
| 1 | 会内締切 | 参加者確定 |
| 2 | 大会申込 | 申込書作成・送付 |
| 3 | 返信待ち | 主催者からの受理連絡待ち |
| 4 | 抽選結果待ち | 抽選がある大会のみ |
| 5 | 参加費支払い | 事前振込の大会のみ |
| 6 | 完了 | 大会当日 |

---

## 技術仕様

### バックエンド

- **フレームワーク**: Sinatra + Sequel ORM
- **データベース**: PostgreSQL
- **認証**: セッションベース（既存の @user 認証を利用）
- **権限**: 管理者は全大会、一般ユーザーは自分が申込した大会のみ

### フロントエンド

- **MVCフレームワーク**: Backbone.js
- **テンプレート**: Underscore.js templates
- **UI**: Foundation 4 + カスタムCSS
- **レイアウト**: Flexbox ベースの横向きフローチャート

### CSV出力

- **エンコーディング**: UTF-8 with BOM（Excel互換）
- **出力項目**: 名前、ふりがな、級、段位、今年度公認大会出場回数

---

## 今後の拡張予定（Phase 2以降）

Phase 1 MVPでは基本的な閲覧・進行機能のみを実装しました。
以下の機能は今後の拡張で対応予定です：

### Phase 2: 詳細情報編集機能

- [ ] 抽選あり/なし、支払方法の設定
- [ ] 申込書送付日、返信受領日の記録
- [ ] 支払期限、振込先情報の管理
- [ ] メモ欄の編集

### Phase 3: 参加費管理

- [ ] 個人別参加費の設定（級別デフォルト値 + 手動調整）
- [ ] 合計金額の自動計算
- [ ] 支払完了/集金完了の記録

### Phase 4: 抽選結果管理

- [ ] 参加者ごとの抽選結果登録（当選/落選/キャンセル待ち）
- [ ] 抽選結果の一括入力機能
- [ ] キャンセル待ちからの繰り上げ管理

---

## テスト項目

マイグレーション実行後、以下をテストしてください：

### 基本動作

1. [ ] トップバーに「申込管理」メニューが表示される
2. [ ] 申込管理画面が開く
3. [ ] 締切後・参加者ありの大会が一覧に表示される
4. [ ] 大会名クリックで詳細画面が開く
5. [ ] フローチャートが正しく表示される

### 管理者機能

6. [ ] 「申込書作成用データ確認」で参加者情報が表示される
7. [ ] 「CSV出力」でファイルがダウンロードされる
8. [ ] CSV内容が正しい（名前、ふりがな、級、段位、出場回数）
9. [ ] 「次のステップに進む」で確認ダイアログが出る
10. [ ] ステップ進行後、フローチャートが更新される

### 一般ユーザー機能

11. [ ] 一般ユーザーは自分が申込した大会のみ表示される
12. [ ] 一般ユーザーは詳細閲覧のみ可能（編集ボタンなし）

### 権限チェック

13. [ ] 一般ユーザーが他人の大会にアクセスすると403エラー
14. [ ] 管理者以外がCSV出力すると403エラー
15. [ ] 管理者以外がステップ進行すると403エラー

---

## トラブルシューティング

### マイグレーションエラー

**エラー**: `column "xxx" already exists`

→ すでにマイグレーションが実行されています。以下で確認:

```sql
SELECT version FROM schema_info;
```

11 が表示されていればOKです。

### 画面が表示されない

1. リソースバージョンを更新したか確認
2. ブラウザのキャッシュをクリア
3. コンソールエラーを確認（F12 → Console）

### CSS/JSが読み込まれない

開発環境の場合、CoffeeScript/SCSSのコンパイルが必要です:

```bash
# CoffeeScriptのコンパイル確認
coffee -c views/js/application_flow.coffee

# SCSSのコンパイル確認
sass views/sass/application_flow.scss public/css/application_flow.css
```

本番環境では `deploy/make` でビルドが必要です。

---

## 参考資料

- [要件定義書 v1.0](./application_flow_requirements_v1.md)
- [要件定義ドラフト](./application_flow_requirements_draft.md)
- [既存機能] `routes/event.rb`, `models/event.rb`
- [類似機能] 大会結果のExcel出力（`inits/helpers/result_excel.rb`）

---

## 変更履歴

- 2026-03-03: Phase 1 MVP実装完了
