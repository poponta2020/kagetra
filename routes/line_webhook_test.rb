# -*- coding: utf-8 -*-
# !! 一時ファイル: LINEグループID取得後に削除すること !!
# LINEグループにボットを招待し、グループ内でメッセージを送信すると
# このエンドポイントにWebhookが届き、グループIDがログに出力される

class MainApp < Sinatra::Base
  post '/api/line_webhook_test' do
    body_str = request.body.read
    data = JSON.parse(body_str) rescue {}

    (data['events'] || []).each do |event|
      source = event['source'] || {}
      if source['type'] == 'group'
        puts "=== LINE GROUP ID 取得 ==="
        puts "GroupId: #{source['groupId']}"
        puts "UserId:  #{source['userId']}"
        puts "=========================="
      end
    end

    status 200
    'OK'
  end
end
