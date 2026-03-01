# LINE添付ファイル通知 実装計画書

## 概要

T-01バッチ（毎朝8時）でLINEに大会案内を送る際、
添付ファイル（PDF/Word）があれば全ページ画像に変換してLINEに送信する。

## 確定仕様

| 項目 | 仕様 |
|------|------|
| 対象通知 | T-01（新規大会案内）のみ |
| タイミング | 翌朝8時バッチで一括送信 |
| 対象ファイル | PDF / Word(.doc/.docx) |
| 複数添付 | 最初の1ファイルのみ送信（created_at が最古） |
| ページ数 | 全ページ（1ページ=1メッセージ） |
| 変換失敗時 | スキップしてテキストのみ送信、エラーログ出力 |
| 画像品質 | 150dpi相当（約1240×1754px） |
| 添付なし | テキストのみ（現状維持） |

## 処理フロー

```
T-01バッチ実行
  ↓
大会のattached_count > 0 を確認
  ↓
添付ファイル一覧取得（最古の1件）
  ↓
ファイル種別判定（orig_nameの拡張子）
  ├─ PDF  → RMagick で JPG変換
  └─ Word → LibreOffice → PDF → RMagick → JPG変換
  ↓
変換画像を storage/line_tmp/{event_id}/ に保存
  ↓
テキストメッセージ送信（現状通り）
  ↓
画像メッセージ送信（ページ順、1枚ずつ）
  ↓
一時ファイル削除
```

## LINE画像メッセージの仕様

- LINE API: `originalContentUrl` と `previewImageUrl` に公開HTTPSのURLが必要
- 認証なしでアクセス可能なエンドポイントが必要
- Content-Type: `image/jpeg`

## 実装ファイル一覧

### 新規作成
| ファイル | 役割 |
|----------|------|
| `lib/document_converter.rb` | PDF/Word → JPG変換ロジック |

### 修正
| ファイル | 変更内容 |
|----------|----------|
| `lib/line_sender.rb` | 画像メッセージ送信メソッド追加 |
| `routes/event.rb` | 一時画像の公開配信エンドポイント追加 |
| `bin/send_notifications.rb` | T-01に画像送信処理追加 |

### サーバー作業
| 作業 | 内容 |
|------|------|
| LibreOfficeインストール | `sudo yum install libreoffice` |

## 実装詳細

### 1. 公開エンドポイント（`routes/event.rb`）

```ruby
# 一時変換画像の公開配信（認証不要、LINE用）
# /public/line_tmp/:token/:filename
get '/public/line_tmp/:token/:filename' do
  path = File.join(CONF_STORAGE_DIR, 'line_tmp', params[:token], params[:filename])
  halt 404 unless File.exist?(path)
  content_type 'image/jpeg'
  send_file path
end
```

トークンは `event.id` のSHA256ハッシュ（推測困難）。

### 2. ドキュメント変換（`lib/document_converter.rb`）

```ruby
class DocumentConverter
  TMP_DIR = File.join(CONF_STORAGE_DIR, 'line_tmp')
  DPI = 150

  # PDF/Wordファイルを JPG画像の配列（パス）に変換
  # 戻り値: ["/path/to/page1.jpg", "/path/to/page2.jpg", ...]
  def self.to_images(file_path, orig_name, event_id)
    ext = File.extname(orig_name).downcase
    token = Digest::SHA256.hexdigest("line-img-#{event_id}")[0, 16]
    out_dir = File.join(TMP_DIR, token)
    FileUtils.mkdir_p(out_dir)

    pdf_path = if ['.doc', '.docx'].include?(ext)
      word_to_pdf(file_path, out_dir)
    else
      file_path
    end

    pdf_to_images(pdf_path, out_dir)
  rescue => e
    puts "  変換エラー: #{e.message}"
    []
  end

  def self.cleanup(event_id)
    token = Digest::SHA256.hexdigest("line-img-#{event_id}")[0, 16]
    FileUtils.rm_rf(File.join(TMP_DIR, token))
  end

  private

  def self.word_to_pdf(file_path, out_dir)
    system("libreoffice --headless --convert-to pdf --outdir #{out_dir} #{file_path}")
    Dir.glob(File.join(out_dir, '*.pdf')).first
  end

  def self.pdf_to_images(pdf_path, out_dir)
    images = Magick::Image::read(pdf_path) { self.density = "#{DPI}" }
    images.each_with_index.map do |img, i|
      out_path = File.join(out_dir, "page#{i+1}.jpg")
      img.write(out_path) { self.quality = 85 }
      out_path
    end
  end
end
```

### 3. LINE画像送信（`lib/line_sender.rb`）

```ruby
def self.send_images_to_group(token, group_id, image_urls)
  # LINEは1リクエストに最大5メッセージ
  image_urls.each_slice(5) do |urls|
    messages = urls.map do |url|
      { type: 'image', originalContentUrl: url, previewImageUrl: url }
    end
    # 既存のsend_to_groupを画像メッセージ対応に拡張
    send_messages_to_group(token, group_id, messages)
  end
end
```

### 4. バッチスクリプト修正（`bin/send_notifications.rb`）

T-01の `line_notify_by_grade` 呼び出し後に追記:

```ruby
# 添付ファイルを画像変換してLINEに送信
if ev.attached_count > 0
  attached = ev.attacheds_dataset.order(Sequel.asc(:created_at)).first
  if attached
    ext = File.extname(attached.orig_name).downcase
    if ['.pdf', '.doc', '.docx'].include?(ext)
      file_path = File.join(CONF_STORAGE_DIR, 'attached', 'event', attached.path)
      images = DocumentConverter.to_images(file_path, attached.orig_name, ev.id)
      unless images.empty?
        token = Digest::SHA256.hexdigest("line-img-#{ev.id}")[0, 16]
        base_url = "https://hokudaicarta.com"
        image_urls = images.each_with_index.map do |_, i|
          "#{base_url}/public/line_tmp/#{token}/page#{i+1}.jpg"
        end
        line_notify_images_by_grade(ev, image_urls)
        DocumentConverter.cleanup(ev.id)
      end
    end
  end
end
```

## 実装手順

- [ ] **Step 1**: 本番サーバーにLibreOfficeインストール・動作確認
- [ ] **Step 2**: `lib/document_converter.rb` 作成
- [ ] **Step 3**: `lib/line_sender.rb` に画像送信メソッド追加
- [ ] **Step 4**: `routes/event.rb` に公開エンドポイント追加
- [ ] **Step 5**: `bin/send_notifications.rb` 修正
- [ ] **Step 6**: ローカルDocker環境でテスト
- [ ] **Step 7**: 本番デプロイ・動作確認

## 注意事項

- `storage/line_tmp/` は `.gitignore` に追加する
- Word変換はLibreOfficeが必要（本番のみ対応、Docker環境ではPDFのみ）
- 大量ページのPDFはバッチ処理時間が長くなる可能性あり
