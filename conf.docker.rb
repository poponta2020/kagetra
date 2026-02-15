# -*- coding: utf-8 -*-
# Docker開発環境用の設定ファイル
# conf.rb.sample をベースに Docker 用に調整

## 滅多に変更する必要のないもの

G_APP_NAME = "景虎"

G_MOBILE_BASE = "/mobile"

G_WEEKDAY_JA = ['日','月','火','水','木','金','土']

G_ADDRBOOK_CONFIRM_STR = 'kagetra_addrbook'

G_SESSION_COOKIE_NAME = "kagetra.session"
G_PERMANENT_COOKIE_NAME = "kagetra.permanent"

G_NEWLY_DAYS_MAX = 75
G_DEADLINE_ALERT = 7
G_LOGIN_LOG_DAYS = 10
G_TOKEN_EXPIRE_HOURS = 24

G_EVENT_KINDS = {party:"コンパ/合宿/アフター等",etc:"アンケート/購入/その他"}

G_TEAM_SIZES = {"1"=>"個人戦","3"=>"三人団体戦","5"=>"五人団体戦"}

G_TOP_BAR_PRIVATE = [
  {route:"top",      name:"TOP"},
  {route:"bbs",      name:"掲示板"},
  {route:"result",   name:"大会結果"},
  {route:"schedule", name:"予定表"},
  {route:"wiki",     name:"Wiki"},
  {route:"album",    name:"アルバム"},
  {route:"map",    name:"地図"},
  {route:"addrbook", name:"名簿"},
]

G_TOP_BAR_PUBLIC = [
  {route:"bbs",      name:"公開掲示板"},
  {route:"schedule", name:"公開予定表"},
  {route:"result_list", name:"入賞歴"},
  {route:"event_catalog", name:"大会/行事案内"},
  {route:"wiki#page/41", name:"役職"},
  {route:"wiki#page/15", name:"練習会場"},
]

G_SINGLE_POINT = [1,2,4,8,16,32,64]
G_SINGLE_POINT_LOCAL = [1,2,4,8,16,32,64,128,256]
G_TEAM_POINT_LOCAL = [10,20,30,40,50]

## 設定

CONF_STORAGE_DIR = "./storage"

CONF_MAP_TILE_URL = "http://tile.openstreetmap.org"

CONF_USE_SSL = false # Docker開発環境ではSSLを無効化

CONF_SESSION_SECRET = "docker_dev_session_secret_kagetra_2024_fixed_value"

# Docker環境のDB接続設定
CONF_DB_USERNAME = "kagetra"
CONF_DB_PASSWORD = "kagetra"
CONF_DB_HOST = "db"
CONF_DB_PORT = 5432
CONF_DB_DATABASE = "kagetra"
CONF_DB_OSM_DATABASE = nil # 地図検索機能は無効化

CONF_DB_DEBUG = true

CONF_LOG_SIZE = 32

CONF_INITIAL_ATTRIBUTES = {
  "全員" => ["全員"],
  "性" => ["男","女"],
  "学年" => ["1年","2年","3年","4年","院生","社会人"],
  "級" => ["A級","B級","C級","D級","E級"],
  "段位" => ["0","1","2","3","4","5","6","7","8","9"],
  "全日協" => ["○","×"]
}
CONF_CONTEST_DEFAULT_AGGREGATE_ATTR = "級"
CONF_CONTEST_DEFAULT_FORBIDDEN_ATTRS = {"全日協" => ["×"]}
CONF_PARTY_DEFAULT_AGGREGATE_ATTR = "学年"
CONF_PROMOTION_ATTRS = ["級","段位"]

CONF_ADDRBOOK_KEYS = ['名前','ふりがな','E-Mail','生年月日','所属','出身高校','電話番号','郵便番号1','住所1','郵便番号2','住所2','メモ1','メモ2']

CONF_ALBUM_LARGE_SIZE = 480000
CONF_ALBUM_LARGE_QUALITY = 92
CONF_ALBUM_THUMB_SIZE = 30000
CONF_ALBUM_THUMB_QUALITY = 87
CONF_FIRST_LOGIN_MESSAGE = "競技かるた会用グループウェア「景虎」へようこそ．<br/>「その他」&rArr;「ユーザ設定」でパスワード変更できます．"

CONF_DUMP_DIR = "backups/dumps/"

CONF_BKUP_MAIL_TO=""
CONF_BKUP_MAIL_ENC_PASSWORD=""
CONF_BACKUP_SMTP_HOST=""
CONF_BACKUP_SMTP_PORT=""
CONF_BACKUP_SMTP_USER=""
CONF_BACKUP_SMTP_PASSWORD=""
CONF_BACKUP_SMTP_FROM=""
CONF_BACKUP_SMTP_TLS_TRUST_FILE=""
CONF_BACKUP_SMTP_LOGFILE=""
CONF_BKUP_WORKDIR = "backups/workdir/"
CONF_BKUP_MAIL_SUBJECT=""
CONF_BKUP_MAIL_BODY=""
CONF_BKUP_MAIL_SPLIT_SIZE="20MB"
