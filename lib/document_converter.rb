# -*- coding: utf-8 -*-
# PDF/Word → JPG変換ユーティリティ（LINE画像送信用）
require 'fileutils'
require 'digest'
require 'tmpdir'

class DocumentConverter
  DPI = 150
  JPEG_QUALITY = 85
  SUPPORTED_EXTS = ['.pdf', '.doc', '.docx'].freeze

  # PDF/Wordファイルを JPG画像パスの配列に変換する
  # 戻り値: ["storage/line_tmp/{token}/page1.jpg", ...] or []
  def self.to_images(file_path, orig_name, event_id)
    ext = File.extname(orig_name.to_s).downcase
    return [] unless SUPPORTED_EXTS.include?(ext)
    return [] unless File.exist?(file_path)

    token = token_for(event_id)
    out_dir = File.join(CONF_STORAGE_DIR, 'line_tmp', token)
    FileUtils.mkdir_p(out_dir)

    pdf_path = if ['.doc', '.docx'].include?(ext)
      word_to_pdf(file_path, out_dir)
    else
      file_path
    end

    return [] if pdf_path.nil?

    pdf_to_images(pdf_path, out_dir)
  rescue => e
    puts "  [DocumentConverter] 変換エラー: #{e.message}"
    []
  end

  # 一時ファイルを削除する
  def self.cleanup(event_id)
    dir = File.join(CONF_STORAGE_DIR, 'line_tmp', token_for(event_id))
    FileUtils.rm_rf(dir)
  end

  def self.token_for(event_id)
    Digest::SHA256.hexdigest("line-img-#{event_id}")[0, 16]
  end

  private

  # Word → PDF変換（LibreOffice使用）
  def self.word_to_pdf(file_path, out_dir)
    # LibreOfficeはシンボリックリンクや特殊パスが苦手なので絶対パスを使用
    abs_path = File.expand_path(file_path)
    abs_out_dir = File.expand_path(out_dir)

    result = system(
      'libreoffice', '--headless', '--convert-to', 'pdf',
      '--outdir', abs_out_dir, abs_path
    )
    unless result
      puts "  [DocumentConverter] LibreOffice変換失敗"
      return nil
    end

    # 変換されたPDFファイルを探す
    base = File.basename(abs_path, '.*')
    pdf = File.join(abs_out_dir, "#{base}.pdf")
    File.exist?(pdf) ? pdf : nil
  end

  # PDF → JPG変換（RMagick使用）
  def self.pdf_to_images(pdf_path, out_dir)
    abs_pdf = File.expand_path(pdf_path)
    images = Magick::Image::read(abs_pdf) { self.density = DPI.to_s }

    images.each_with_index.map do |img, i|
      out_path = File.join(out_dir, "page#{i + 1}.jpg")
      img.write(out_path) { self.quality = JPEG_QUALITY }
      out_path
    end
  end
end
