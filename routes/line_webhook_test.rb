
# -*- coding: utf-8 -*-

class MainApp < Sinatra::Base

  post '/api/line_webhook_test' do

    data = @json || {}



    (data['events'] || []).each do |event|

      source = event['source'] || {}

      if source['type'] == 'group'

        File.open('/tmp/line_group_ids.txt', 'a') do |f|

          f.puts "GroupId: #{source['groupId']}"

          f.puts "UserId:  #{source['userId']}"

          f.puts "---"

        end

      end

    end



    status 200

    'OK'

  end

end

