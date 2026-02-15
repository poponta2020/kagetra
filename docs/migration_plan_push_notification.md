# Push通知機能 本番移行計画書

## 概要

Push通知機能（Web Push API + Service Worker）を本番環境にデプロイするための手順書。

**前提条件:**
- 本番環境: rbenv + Unicorn + nginx 構成
- HTTPS 有効済み（Service Worker の動作に必須）
- cron 使用中（バックアップジョブ等）

**本番環境情報:**
- インストールディレクトリ: `/home/kagetra/kagetra`
- 実行ユーザー: `kagetra`
- ロールバック用コミット: `eeaad91`

**表記:**
- `$DB_USER` = PostgreSQL ユーザー名（`conf.rb` の `CONF_DB_USERNAME`）
- `$DB_NAME` = PostgreSQL データベース名（`conf.rb` の `CONF_DB_DATABASE`）

---

## 手順一覧

| # | 作業 | 所要時間目安 | サービス停止 | 進捗 |
|---|------|------------|------------|------|
| 1 | 事前バックアップ | 1分 | 不要 | **完了** |
| 2 | Unicorn停止 | 数秒 | **停止** | **完了** |
| 3 | コード更新 + gem インストール | 1〜2分 | 停止中 | **完了** |
| 4 | アセットコンパイル | 数秒 | 停止中 | **完了** |
| 5 | VAPID鍵生成 + conf.rb 追記 | 1分 | 停止中 | **完了** |
| 6 | DBマイグレーション | 数秒 | 停止中 | **完了** |
| 7 | Unicorn起動 | 数秒 | **復旧** | **完了** |
| 8 | 動作確認 | 2〜3分 | 不要 | **完了** |
| 9 | cronジョブ追加 | 1分 | 不要 | **完了** |

**想定ダウンタイム: 3〜5分**

---

## 1. 事前バックアップ

サーバーにSSHでログインし、以下を実行する。

```bash
# 景虎ディレクトリに移動
cd $KAGETRA

# 現在のコミットハッシュを控える（ロールバック用）
git log --oneline -1
# 実行結果: eeaad91 (HEAD -> master, origin/master, origin/HEAD) modify session cookie setting
# → ロールバック用コミット: eeaad91 [完了]
```

```bash
# データベースのバックアップ
./scripts/with_rbenv.sh ./periodic_dbdump.sh

# バックアップファイルの確認
ls -la backups/dumps/
# 実行結果: pgdump_2026-02-15_152647 (468374 bytes) [完了]
```

---

## 2. Unicorn停止

```bash
cd $KAGETRA

# Unicornを停止（この時点でサービスが停止する）
./scripts/unicorn_ctl.sh stop
# 出力: killing pid=XXXXX
```

```bash
# プロセスが終了したことを確認（何も表示されなければOK）
sleep 2
cat deploy/pid/unicorn.pid 2>/dev/null && echo "まだ停止していません" || echo "停止確認OK"
```

---

## 3. コード更新 + gem インストール

```bash
cd $KAGETRA

# 最新コードを取得
git fetch origin
git checkout master
git pull origin master
```

```bash
# 新しい gem (web-push) をインストール
bundle install

# web-push がインストールされたことを確認
bundle list | grep web-push
# 出力例: * web-push (x.x.x)  ← バージョンが表示されればOK
```

---

## 4. アセットコンパイル

CoffeeScript（`views/js/user_conf.coffee`）が変更されているため、
本番用の圧縮済み JavaScript を再生成する。

```bash
cd $KAGETRA/deploy

# CoffeeScript と Sass をコンパイル
make

cd $KAGETRA
```

---

## 5. VAPID鍵生成 + conf.rb 追記

### 5-1. VAPID鍵ペアを生成する

```bash
cd $KAGETRA

bundle exec ruby -e "require 'web-push'; keys = WebPush.generate_key; puts 'PUBLIC: ' + keys.public_key; puts 'PRIVATE: ' + keys.private_key"
```

出力例:
```
PUBLIC:  BMxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx=
PRIVATE: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx=
```

**この2行を控える（次の手順で使用）。**

### 5-2. conf.rb の末尾に追記する

```bash
cd $KAGETRA

# エディタで conf.rb を開く
vi conf.rb
```

ファイル末尾に以下の3行を追記する。`<PUBLIC鍵>` と `<PRIVATE鍵>` は手順 5-1 の出力で置き換える。

```ruby
# Web Push (VAPID) 設定
CONF_VAPID_PUBLIC_KEY = "<5-1で出力されたPUBLIC鍵>"
CONF_VAPID_PRIVATE_KEY = "<5-1で出力されたPRIVATE鍵>"
CONF_VAPID_SUBJECT = "mailto:<管理者のメールアドレス>"
```

保存して閉じる（vi の場合: `:wq`）。

```bash
# 追記内容の確認（末尾4行を表示）
tail -4 conf.rb
# CONF_VAPID_PUBLIC_KEY, CONF_VAPID_PRIVATE_KEY, CONF_VAPID_SUBJECT が表示されればOK
```

**注意:**
- VAPID鍵は一度設定したら変更しないこと。変更すると全ユーザーの購読が無効になる。
- `conf.rb` は `.gitignore` に含まれておりリポジトリにコミットされないため、秘密情報の漏洩リスクはない。

---

## 6. DBマイグレーション

新規テーブル2つ（`push_subscriptions`, `notification_settings`）を作成する。
`CREATE TABLE IF NOT EXISTS` を使用しているため、誤って2回実行しても安全。

```bash
cd $KAGETRA

# マイグレーション実行
psql -U $DB_USER -d $DB_NAME -f db/migrations/001_create_push_tables.sql
```

出力例:
```
CREATE TABLE
CREATE TABLE
```

```bash
# テーブルが作成されたことを確認
psql -U $DB_USER -d $DB_NAME -c "\dt push_subscriptions; \dt notification_settings"
```

出力に `push_subscriptions` と `notification_settings` の2行が表示されればOK。

---

## 7. Unicorn起動

```bash
cd $KAGETRA

# Unicornを起動（この時点でサービスが復旧する）
./scripts/unicorn_ctl.sh start
# 出力: unicorn started
```

```bash
# プロセスが起動したことを確認
sleep 2
cat deploy/pid/unicorn.pid
# PID番号が表示されればOK
```

```bash
# ログにエラーがないことを確認
tail -20 deploy/log/production.log
# エラー（ERROR / Exception）がなければOK
```

---

## 8. 動作確認

ブラウザで景虎にアクセスし、以下を順番に確認する。

### 8-1. 既存機能の確認

| # | 確認項目 | 操作 | 期待結果 |
|---|---------|------|---------|
| 1 | ログイン | ブラウザでアクセスしてログイン | 正常にログインできる |
| 2 | TOP画面 | ログイン後のTOP画面を確認 | 大会/行事一覧、お知らせが表示される |
| 3 | 掲示板 | メニューから「掲示板」を開く | スレッド一覧が表示される |

### 8-2. 通知機能の確認

| # | 確認項目 | 操作 | 期待結果 |
|---|---------|------|---------|
| 4 | manifest.json | `https://<ドメイン>/manifest.json` にアクセス | JSON が表示される |
| 5 | ユーザ設定画面 | 「その他」→「ユーザ設定」 | 「通知設定」セクションが表示される |
| 6 | 通知の有効化 | 「通知を有効にする」ボタンをクリック | ブラウザの通知許可ダイアログが表示される |
| 7 | 許可後の表示 | 通知を許可する | 「この端末では通知が有効です。」と表示される |
| 8 | 通知設定チェックボックス | 通知有効化後に画面を確認 | 4つのチェックボックスが表示される |
| 9 | Service Worker | DevTools → Application → Service Workers | `sw.js` が Activated 状態 |

### 8-3. テスト通知の送信（任意）

```bash
cd $KAGETRA

# 購読者がいることを確認
psql -U $DB_USER -d $DB_NAME -c "SELECT user_id, LEFT(endpoint, 60) FROM push_subscriptions;"

# テスト通知を送信
bundle exec ruby bin/test_notification.rb
# 出力に「成功 1件」等が表示され、ブラウザに通知が届けばOK
```

---

## 9. cronジョブの追加

通知バッチを毎日 JST 8:00 に実行するジョブを追加する。
既存のバックアップジョブと同じ `with_rbenv.sh` ラッパーを使用する。

```bash
# 現在のcron設定を確認（既存ジョブを把握）
crontab -l
```

```bash
# cron編集画面を開く
crontab -e
```

以下の2行を末尾に追記する（`$KAGETRA` は実際のパスに置き換え）:

```cron
# Push通知バッチ（毎日 JST 8:00 = UTC 23:00）
0 23 * * * $KAGETRA/scripts/with_rbenv.sh bundle exec ruby $KAGETRA/bin/send_notifications.rb >> $KAGETRA/deploy/log/notification.log 2>&1
```

保存して閉じる。

```bash
# 追加されたことを確認
crontab -l | grep notification
# 上記で追加した行が表示されればOK
```

**補足:**
- `with_rbenv.sh` が rbenv 環境を自動セットアップする（既存のバックアップジョブと同じ仕組み）
- ログは `deploy/log/notification.log` に出力される
- 対象イベントがなければ何もせず正常終了する（安全）

---

## ロールバック手順

問題が発生した場合、以下の手順で移行前の状態に戻す。

### R-1. Unicorn停止

```bash
cd $KAGETRA
./scripts/unicorn_ctl.sh stop
```

### R-2. コードを元に戻す

```bash
cd $KAGETRA

# 手順1で控えたコミットハッシュに戻す
git checkout <控えたコミットハッシュ>

# gem を元に戻す
bundle install

# アセットを再コンパイル
cd deploy && make && cd ..
```

### R-3. conf.rb のVAPID設定を削除

```bash
cd $KAGETRA
vi conf.rb
# 手順5-2で追記した CONF_VAPID_* の3行を削除
# 保存して閉じる (:wq)
```

### R-4. cronジョブを削除

```bash
crontab -e
# 手順9で追加した notification 関連の2行を削除
# 保存して閉じる
```

### R-5. DBテーブルの削除（任意）

テーブルを残しても既存機能に影響はないが、完全に元に戻す場合は実行する。

```bash
psql -U $DB_USER -d $DB_NAME -c "DROP TABLE IF EXISTS notification_settings; DROP TABLE IF EXISTS push_subscriptions;"
```

### R-6. Unicorn起動

```bash
cd $KAGETRA
./scripts/unicorn_ctl.sh start
```

---

## 変更ファイル一覧

| ファイル | 変更種別 | 内容 |
|---------|---------|------|
| `Gemfile` | 変更 | `web-push` gem 追加 |
| `Gemfile.lock` | 変更 | lock更新 |
| `conf.docker.rb` | 変更 | VAPID設定追加（開発用のみ、本番は `conf.rb`） |
| `inits/init.rb` | 変更 | `G_RESOURCE_VERSION` 26→27 |
| `models/init.rb` | 変更 | `push` モデル読み込み追加 |
| `models/push.rb` | **新規** | PushSubscription / NotificationSetting モデル |
| `routes/init.rb` | 変更 | `push` ルート読み込み追加 |
| `routes/push.rb` | **新規** | Push API エンドポイント（5本） |
| `lib/web_push_sender.rb` | **新規** | Web Push 送信ユーティリティ |
| `bin/send_notifications.rb` | **新規** | 通知バッチスクリプト |
| `db/migrations/001_create_push_tables.sql` | **新規** | DBマイグレーション |
| `public/sw.js` | **新規** | Service Worker |
| `public/manifest.json` | **新規** | PWA マニフェスト |
| `views/layout.haml` | 変更 | manifest link + SW登録スクリプト追加 |
| `views/user_conf.haml` | 変更 | 通知設定UIテンプレート追加 |
| `views/js/user_conf.coffee` | 変更 | 通知設定ビュー追加 |
| `docker/entrypoint.dev.sh` | 変更 | SQLマイグレーション実行追加（開発環境用） |
| `docs/notification_plan.md` | **新規** | 要件定義書 |
| `docs/mobile_app_feasibility.md` | **新規** | モバイルアプリ調査資料 |

---

## 注意事項

- **VAPID鍵は秘密情報**として扱うこと。`conf.rb` は `.gitignore` に含まれており、リポジトリにコミットされない
- `conf.rb.sample` にはVAPID設定のテンプレートが含まれていないため、手順 5-2 を必ず実施すること
- nginx は `public/` ディレクトリの静的ファイルを直接配信するため、`sw.js` と `manifest.json` は git pull 後すぐに配信可能になる
- ユーザーが通知を有効にしない限り、既存の動作には一切影響しない
