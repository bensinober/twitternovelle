#encoding: UTF-8
require "rubygems"
require "bundler/setup"
require "sinatra"
require "sinatra-websocket"
require "sinatra/reloader" if development?
require "em-http-request"
require "slim"
require "json"
require "logger"
require "tweetstream"

class APP < Sinatra::Base
  
  CONFIG = YAML::load(File.open("config/config.yml"))
    
  # Twitter API config
  TweetStream.configure do |config|
    config.consumer_key       = CONFIG['twitter']['consumer_key']
    config.consumer_secret    = CONFIG['twitter']['consumer_secret']
    config.oauth_token        = CONFIG['twitter']['oauth_token']
    config.oauth_token_secret = CONFIG['twitter']['oauth_token_secret']
    config.auth_method        = CONFIG['twitter']['auth_method']
    config.parser             = CONFIG['twitter']['parser']
  end
  
  # Sinatra configs
  session = {}
  set :server, 'thin'
  set :sockets, []
  
  # methods
  session[:tweets] = []
  
  # Stop after collecting 10 statuses
  @statuses = []
  TweetStream::Client.new.userstream do |status, client|
    @statuses << status
    client.stop if @statuses.size >= 1
  end

  def start_userstream
    @client = TweetStream::Client.new
    @client.on_error {|error| logger.error("error: #{error.text}") }
    @client.on_direct_message {|direct_message| logger.info("direct message: #{direct_message.text}") }
    @client.on_timeline_status {|status| logger.info("timelinestatus: #{status.text}") }
    #@client.userstream {|status| EM::HttpRequest.new('http://localhost:4000/ws').get :query => "#{status}" }
    @client.userstream {|status| EM.next_tick { settings.sockets.each{|s| s.send(status.to_hash.to_json) } } }
  end
  
  # Routing
  get '/' do
    # start tweetstream
    start_userstream unless @client
    slim :index, :locals => { :tweets => session[:tweets] }
  end
  
  get '/ws' do
    return false unless @request.websocket?
  
    request.websocket do |ws|
  
      ws.onopen do
        #ws.send("Hello World!")
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
