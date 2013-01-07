#encoding: UTF-8
require "rubygems"
require "bundler/setup"
require "sinatra"
require "sinatra-websocket"
require "sinatra/reloader" if development?
require "slim"
require "json"
#require "yajl"
require "logger"
require "tweetstream"

class APP < Sinatra::Base
  
  CONFIG = YAML::load(File.open("config/config.yml"))
  # Twitter API config
  TweetStream.configure do |config|
    config.consumer_key       = CONFIG['consumer_key']
    config.consumer_secret    = CONFIG['consumer_secret']
    config.oauth_token        = CONFIG['oauth_token']
    config.oauth_token_secret = CONFIG['oauth_token_secret']
    config.auth_method        = CONFIG['auth_method']
    config.parser             = CONFIG['parser']
  end
  
  # Sinatra configs
  session = {}
  set :server, 'thin'
  set :sockets, []
  
  # Routing
  get '/' do
    @client = TweetStream::Client.new
     @client.userstream do |res|
       @res = res
     end
    slim :index, locales => { :status => status }
  end
  
  get '/ws' do
    return false unless request.websocket?
  
    request.websocket do |ws|
  
      ws.onopen do
        settings.sockets << ws
      end
  
      ws.onmessage do |msg|
        logger.info("Tweet #{msg} -")
        EM.next_tick { settings.sockets.each{|s| s.send(msg) } }
      end
  
      ws.onclose do
        #warn("websocket closed")
        settings.sockets.delete(ws)
      end
    end
  end
end
