# 景虎 Web Push 通知機能 要件定義書

> このドキュメントは認識合わせに応じて随時更新する。
> 最終更新: 2026-02-15

---

## 1. 目的・スコープ

### 1.1 目的

景虎Webアプリケーションから、ユーザーのスマートフォン（iOS/Android）にプッシュ通知を送れるようにする。

### 1.2 スコープ

- **対象**: Web Push（ブラウザプッシュ通知）による通知機能の追加
- **対象外**: ストア配信、ネイティブアプリ化、既存機能の変更
- Web版は引き続き維持する

### 1.3 前提条件

| 項目 | 値 |
|------|-----|
| 通知方式 | Web Push（Push API + Service Worker + VAPID認証） |
| 配信URL | `https://www.hokudaicarta.com`（HTTPS対応済み） |
| サーバー環境 | AWS Lightsail Linux（cron利用可能、certbot自動更新あり） |
| アクティブユーザー数 | 約50名 |
| 対応ブラウザ | Android Chrome（完全対応）、iOS Safari 16.4+（ホーム画面追加が条件） |

### 1.4 方式選定の経緯

Web Push / LINE Messaging API / Discord Webhook / メール通知 を比較検討した結果、以下の理由で Web Push を選定した。

- コスト0（外部サービスへの依存なし）
- 通知許可はサイト単位で独立（他サイトの通知に影響しない）
- iOS 16.4+ / Android 両対応

---

## 2. 機能要件

### 2.1 通知の購読（ユーザー操作）

| ID | 要件 |
|----|------|
| F-01 | ユーザーがログイン後、ブラウザの通知許可ダイアログを表示できる |
| F-02 | 通知を許可すると、その端末の購読情報がサーバーに保存される |
| F-03 | 1ユーザーが複数端末で購読できる（PC・スマホ等） |
| F-04 | ユーザーが通知を無効化すると、その端末の購読情報が削除される |
| F-05 | 購読の登録・解除はユーザー設定画面から操作できる |

### 2.2 通知設定（ユーザーごとのON/OFF）

| ID | 要件 |
|----|------|
| F-06 | ユーザーが通知種別ごとにON/OFFを設定できる |
| F-07 | 初期状態は全トリガーON |
| F-08 | 設定はユーザー設定画面（`user_conf`）で操作する |

設定可能なトリガー種別:

| 設定項目 | 説明 | デフォルト |
|---------|------|-----------|
| 新規大会/行事追加 | 新しい大会や行事が追加された時 | ON |
| 締切リマインダー | 締切当日の朝に通知 | ON |
| コメント新着 | 登録済み大会にコメントがついた時 | ON |
| [管理者] 締切到来通知 | 大会が締切を迎え、申込処理が必要な時 | ON |

### 2.3 通知トリガーと送信対象

| ID | トリガー | 送信対象 | 通知条件 |
|----|---------|---------|---------|
| T-01 | 新規大会/行事が追加された | 通知ONの全ユーザー | 前日のバッチ実行時刻以降に作成された大会/行事がある |
| T-02 | 締切当日リマインダー | 未登録かつ登録可能なユーザー（forbidden でない） | 当日が締切日である大会がある |
| T-03 | コメント新着 | 当該大会に登録済みのユーザー | 前日のバッチ実行時刻以降にコメントが投稿された |
| T-04 | [管理者] 締切到来 | 管理者（admin / sub_admin） | 参加者がいる大会が締切を迎えた |

### 2.4 通知の送信タイミング

| ID | 要件 |
|----|------|
| F-09 | 通知はバッチ送信とする（リアルタイムではない） |
| F-10 | バッチは毎日1回、JST 午前8:00 に実行する |
| F-11 | バッチスクリプトはcronで起動する（UTC 23:00 = JST 8:00） |

### 2.5 通知メッセージ

| トリガー | タイトル | 本文例 |
|---------|--------|--------|
| T-01 新規大会追加 | 景虎: 新しい大会が追加されました | 「第10回○○大会」(3/15) が追加されました |
| T-02 締切リマインダー | 景虎: 本日締切の大会があります | 「第10回○○大会」の申込締切は本日です |
| T-03 コメント新着 | 景虎: コメントが届きました | 「第10回○○大会」に新しいコメント(2件) |
| T-04 [管理者] 締切到来 | 景虎: 申込処理が必要です | 「第10回○○大会」が締切を迎えました(参加者5名) |

### 2.6 iOS ユーザーへの対応

| ID | 要件 |
|----|------|
| F-12 | PWA マニフェスト（`manifest.json`）を配置し、iOS でホーム画面追加を可能にする |
| F-13 | iOS ユーザーに「ホーム画面に追加」の手順を案内する（ユーザー設定画面に説明文を表示） |

---

## 3. 非機能要件

| ID | 要件 |
|----|------|
| NF-01 | 既存機能に一切影響を与えない（既存テーブル・API・画面への変更なし） |
| NF-02 | 通知を許可しないユーザーには何も影響しない |
| NF-03 | 購読情報が無効（ブラウザ側で通知をブロック等）になった場合、送信失敗した購読を自動削除する |
| NF-04 | バッチスクリプトの実行ログを出力する |
| NF-05 | VAPID 鍵はサーバー上の設定ファイルで管理する（リポジトリにコミットしない） |

---

## 4. 画面仕様

### 4.1 ユーザー設定画面（`user_conf`）への追加

現行の画面構成:
1. 掲示板の外部公開スレに書き込む際の名前
2. パスワード変更

実装後の画面構成:
1. 掲示板の外部公開スレに書き込む際の名前
2. パスワード変更
3. **通知設定（新規追加）**

#### 通知設定セクションの内容

```
■ 通知設定
──────────────────────────────
[通知を有効にする] ボタン  ← ブラウザの許可ダイアログを呼び出す
  ※ 通知が許可済みの場合は [通知を無効にする] ボタンに切替

☑ 新規大会/行事が追加された時に通知する
☑ 締切当日にリマインダーを受け取る
☑ 登録済み大会にコメントがついた時に通知する
☑ [管理者] 締切到来通知を受け取る        ← 管理者のみ表示

[設定を保存] ボタン

※ iOS をお使いの方: Safari で景虎を開き、共有ボタンから
  「ホーム画面に追加」を行ってから通知を有効にしてください。
──────────────────────────────
```

### 4.2 レイアウト（`layout.haml`）への追加

- `<head>` 内に `<link rel="manifest" href="/manifest.json">` を追加
- `<body>` 末尾に Service Worker 登録スクリプトを追加

---

## 5. 技術仕様

### 5.1 全体の処理フロー

```
[毎朝 8:00 JST - cron 起動]
    ↓
[バッチスクリプト bin/send_notifications.rb] (Ruby)
    ├── 今日締切の大会を検索 → 対象ユーザーに通知 (T-02, T-04)
    ├── 前回バッチ以降に追加された新規大会を検索 → 全ユーザーに通知 (T-01)
    └── 前回バッチ以降のコメント新着を検索 → 登録済みユーザーに通知 (T-03)
    ↓
[各ユーザーの通知設定を確認] (notification_settings テーブル)
    ↓
[Web Push 送信] (web-push gem + VAPID 認証)
    └── 各ユーザーの全端末に送信 (push_subscriptions テーブル)
```

### 5.2 DB 追加テーブル

既存テーブルへの変更は一切なし。以下の2テーブルを新規追加する。

```sql
-- Web Push 購読情報（1ユーザーが複数端末で購読可能）
CREATE TABLE push_subscriptions (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  endpoint TEXT NOT NULL,           -- Push サービスの URL
  p256dh TEXT NOT NULL,             -- 公開鍵
  auth TEXT NOT NULL,               -- 認証トークン
  user_agent VARCHAR(255),          -- 端末識別（参考情報）
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,
  UNIQUE(endpoint)                  -- 同じ端末の重複登録を防止
);

-- 通知設定（ユーザーごとにトリガー種別ごとの ON/OFF）
CREATE TABLE notification_settings (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  new_event BOOLEAN NOT NULL DEFAULT TRUE,       -- 新規大会/行事追加
  deadline_reminder BOOLEAN NOT NULL DEFAULT TRUE, -- 締切当日リマインダー
  event_comment BOOLEAN NOT NULL DEFAULT TRUE,    -- 登録済み大会のコメント新着
  admin_deadline BOOLEAN NOT NULL DEFAULT TRUE,   -- [管理者] 締切到来通知
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,
  UNIQUE(user_id)
);
```

### 5.3 API エンドポイント（新規）

| メソッド | パス | 説明 |
|---------|------|------|
| POST | `/api/push/subscribe` | 購読登録（endpoint, p256dh, auth を保存） |
| DELETE | `/api/push/subscribe` | 購読解除（endpoint で特定して削除） |
| GET | `/api/push/settings` | 通知設定の取得 |
| PUT | `/api/push/settings` | 通知設定の更新 |
| GET | `/api/push/vapid_public_key` | VAPID 公開鍵の取得（クライアントが購読時に使用） |

### 5.4 Service Worker（`public/sw.js`）

- `push` イベント: サーバーからの通知ペイロード（JSON）を受信し、`self.registration.showNotification()` で通知表示
- `notificationclick` イベント: 通知クリック時に景虎のトップページを開く

### 5.5 PWA マニフェスト（`public/manifest.json`）

```json
{
  "name": "景虎",
  "short_name": "景虎",
  "start_url": "/top",
  "display": "standalone",
  "background_color": "#ffffff",
  "theme_color": "#003366",
  "icons": [
    { "src": "/img/apple-touch-icon.png", "sizes": "152x152", "type": "image/png" }
  ]
}
```

### 5.6 VAPID 鍵

- 初回デプロイ時に `web-push` gem で VAPID 鍵ペアを生成
- `conf.rb`（本番）/ `conf.docker.rb`（開発）に以下を追記:

```ruby
CONF_VAPID_PUBLIC_KEY = "生成された公開鍵"
CONF_VAPID_PRIVATE_KEY = "生成された秘密鍵"
CONF_VAPID_SUBJECT = "mailto:admin@hokudaicarta.com"
```

### 5.7 cron 設定

```
# サーバーが UTC の場合、JST 8:00 = UTC 23:00（前日）
0 23 * * * cd /path/to/kagetra && ruby bin/send_notifications.rb >> /var/log/kagetra_notify.log 2>&1
```

---

## 6. ファイル一覧

### 6.1 新規ファイル

| # | ファイル | 役割 |
|---|---------|------|
| 1 | `public/sw.js` | Service Worker（通知受信・表示） |
| 2 | `public/manifest.json` | PWA マニフェスト（iOS ホーム画面追加用） |
| 3 | `lib/web_push_sender.rb` | Web Push 送信ロジック（web-push gem のラッパー） |
| 4 | `bin/send_notifications.rb` | cron から実行するバッチスクリプト |
| 5 | `routes/push.rb` | 購読登録/解除 API、通知設定 API |
| 6 | `models/push.rb` | PushSubscription, NotificationSetting モデル |
| 7 | `db/migrations/001_create_push_tables.rb` | DB マイグレーション |

### 6.2 変更ファイル

| # | ファイル | 変更内容 |
|---|---------|---------|
| 1 | `Gemfile` | `gem 'web-push'` を追加 |
| 2 | `views/layout.haml` | manifest.json リンク + Service Worker 登録スクリプト追加 |
| 3 | `views/user_conf.haml` | 通知設定セクションの HTML テンプレート追加 |
| 4 | `views/js/user_conf.coffee` | 通知設定の保存処理、Push 購読の登録/解除ロジック追加 |
| 5 | `inits/init.rb` | VAPID キー設定の読み込み追加 |
| 6 | `routes/init.rb` | `require_relative 'push'` を追加 |
| 7 | `models/init.rb` | `require_relative 'push'` を追加 |
| 8 | `conf.docker.rb` | VAPID 鍵設定を追加（開発用） |

---

## 7. 変更しないもの

以下は一切変更しない:

- 既存の全機能（大会管理、掲示板、カレンダー、アルバム、Wiki 等）
- 既存のDBテーブル（42テーブル）
- 既存のAPIエンドポイント（100以上）
- 既存の画面の見た目・操作（通知設定UIの追加を除く）
- 通知を許可しないユーザーへの影響

---

## 変更履歴

| 日付 | 変更内容 |
|------|---------|
| 2026-02-15 | 初版作成。通知方式の比較、トリガー案、未決定事項を整理 |
| 2026-02-15 | 通知方式を Web Push に決定。DB設計を簡素化 |
| 2026-02-15 | HTTPS対応済みを確認。バッチ送信・cron設定等の全決定事項を反映 |
| 2026-02-15 | 要件定義書として再構成。機能要件・画面仕様・API仕様を整理 |
