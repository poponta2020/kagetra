#!/bin/bash
set -e

cd /app

# conf.rb が存在しない場合、Docker用設定をコピー
if [ ! -f conf.rb ]; then
  echo "==> conf.rb が見つかりません。conf.docker.rb をコピーします..."
  cp conf.docker.rb conf.rb
fi

# bundle install（未インストールの場合）
if [ ! -f /bundle_cache/.installed ]; then
  echo "==> bundle install を実行中..."
  bundle install --path /bundle_cache
  touch /bundle_cache/.installed
else
  echo "==> bundle は既にインストール済みです"
  bundle install --path /bundle_cache --quiet
fi

# bower install（未インストールの場合）
if [ ! -d views/js/libs/jquery ]; then
  echo "==> bower install を実行中..."
  bower install --allow-root
else
  echo "==> bower ライブラリは既にインストール済みです"
fi

# 必要ディレクトリの作成
mkdir -p storage deploy/log deploy/pid deploy/sock

# public/js → views/js シンボリックリンク（Sass の相対パス解決用）
if [ ! -e public/js ]; then
  ln -s ../views/js public/js
  echo "==> public/js → views/js シンボリックリンクを作成しました"
fi

# DB接続待ち
echo "==> PostgreSQL の起動を待っています..."
until PGPASSWORD=$POSTGRES_PASSWORD psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c '\q' 2>/dev/null; do
  echo "  PostgreSQL が準備できていません。2秒後にリトライ..."
  sleep 2
done
echo "==> PostgreSQL に接続しました"

# DBマイグレーション + 初期データ投入（初回のみ）
if ! PGPASSWORD=$POSTGRES_PASSWORD psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT 1 FROM users WHERE name='admin' LIMIT 1" 2>/dev/null | grep -q "1 row"; then
  echo "==> DB初期化を実行中..."
  # 1回目: マイグレーション（テーブル作成）、2回目: 初期データ投入
  bundle exec ruby scripts/initial_config.rb -p kagetora || true
  bundle exec ruby scripts/initial_config.rb -p kagetora
  echo "==> DB初期化完了（共有パスワード: kagetora）"
else
  echo "==> DB は既に初期化済みです"
fi

# Push通知用テーブルのマイグレーション
echo "==> Push通知テーブルのマイグレーション..."
for f in db/migrations/*.sql; do
  if [ -f "$f" ]; then
    PGPASSWORD=$POSTGRES_PASSWORD psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f "$f" 2>/dev/null || true
  fi
done

echo "==> アプリケーションを起動中 (http://0.0.0.0:9292) ..."
exec bundle exec rackup -o 0.0.0.0 -p 9292
