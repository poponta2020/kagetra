# -*- coding: utf-8 -*-
# LINE Messaging API グループメッセージ送信
require 'net/http'
require 'net/https'
require 'json'

class LineSender
  LINE_PUSH_URL = 'https://api.line.me/v2/bot/message/push'

  # 級の属性値IDに対応するLINEグループへメッセージを送信する
  # attr_value_id: UserAttributeValue の id (10=A級, 11=B級, ...)
  def self.send_to_grade(attr_value_id, message)
    return unless defined?(LINE_GROUP_BOTS)
    config = LINE_GROUP_BOTS[attr_value_id]
    return unless config
    return if config[:token].to_s.empty? || config[:group_id].to_s.empty?

    result = send_to_group(config[:token], config[:group_id], message)
    puts "  LINE送信 #{config[:name]}: #{result ? 'OK' : 'FAIL'}"
    result
  end

  # 指定したグループへメッセージを送信する
  def self.send_to_group(token, group_id, message)
    uri = URI(LINE_PUSH_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    req = Net::HTTP::Post.new(uri.path)
    req['Authorization'] = "Bearer #{token}"
    req['Content-Type'] = 'application/json'
    req.body = { to: group_id, messages: [{ type: 'text', text: message }] }.to_json

    res = http.request(req)
    if res.code != '200'
      puts "  LINE APIエラー: #{res.code} #{res.body}"
      return false
    end
    true
  rescue => e
    puts "  LINE送信例外: #{e.message}"
    false
  end
end
