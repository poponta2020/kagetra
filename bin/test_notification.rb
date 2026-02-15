
# -*- coding: utf-8 -*-

require_relative '../inits/init'

require_relative '../lib/web_push_sender'

payload = {

  title: "\u666f\u864e: \u30c6\u30b9\u30c8\u901a\u77e5",

  body: "Push\u901a\u77e5\u306e\u30c6\u30b9\u30c8\u9001\u4fe1\u3067\u3059 (#{Time.now.strftime('%H:%M:%S')})",

  url: "/top"

}

subs = PushSubscription.all

if subs.empty?

  puts "\u8cfc\u8aad\u8005\u304c\u3044\u307e\u305b\u3093\u3002\u30d6\u30e9\u30a6\u30b6\u3067\u901a\u77e5\u3092\u6709\u52b9\u306b\u3057\u3066\u304f\u3060\u3055\u3044\u3002"

  exit 1

end

subs.each do |sub|

  user = User[sub.user_id]

  name = user ? user.name : sub.user_id

  begin

    WebPushSender.send_notification(sub, payload)

    puts "OK: #{name}"

  rescue => e

    puts "NG: #{name} (#{e.message})"

  end

end

