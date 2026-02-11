# rack-coffee gem の代替実装
# オリジナルの rack-coffee gem は rubygems.org から削除されたため、
# 必要最小限の機能をローカルに実装
require 'coffee-script'

module Rack
  class Coffee
    def initialize(app, opts = {})
      @app = app
      @root = opts[:root] || Dir.pwd
      @urls = Array(opts[:urls] || '/javascripts')
      @cache_compile = opts[:cache_compile] || false
      @compiled = {}
    end

    def call(env)
      path = env['PATH_INFO']
      @urls.each do |url|
        if path.start_with?(url) && path.end_with?('.js')
          coffee_path = ::File.join(@root, path.sub(/\.js$/, '.coffee'))
          if ::File.exist?(coffee_path)
            mtime = ::File.mtime(coffee_path)
            js = if @cache_compile && @compiled[coffee_path] && @compiled[coffee_path][:mtime] == mtime
              @compiled[coffee_path][:js]
            else
              compiled = CoffeeScript.compile(::File.read(coffee_path, encoding: 'UTF-8'))
              @compiled[coffee_path] = { js: compiled, mtime: mtime } if @cache_compile
              compiled
            end
            return [200, {'Content-Type' => 'application/javascript'}, [js]]
          end
        end
      end
      @app.call(env)
    end
  end
end
