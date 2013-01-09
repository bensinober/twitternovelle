#encoding: UTF-8
require "rubygems"
require "bundler/setup"
require "sinatra/base"
require "sinatra-websocket"
require "sinatra/reloader"
require "em-http-request"
require "slim"
require "yajl"
require "yajl/json_gem"
require "logger"
require "tweetstream"

class APP < Sinatra::Base

  # Sinatra configs
  set :static, true
  set :root, File.dirname(__FILE__)
  session = {}
  set :server, 'thin'
  set :sockets, []

  
  configure :production, :development do
   enable :logging
  end
  
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
  
  # to be used later for logging
  session[:tweets] = []

  # class methods  
  def stream(run=true)
    if run
      # make sure we don't create multiple streams
      @client = TweetStream::Client.new unless @client
      @client.on_error {|error| logger.error("error: #{error.text}") }
      @client.on_direct_message {|direct_message| logger.info("direct message: #{direct_message.text}") }
      @client.on_timeline_status {|status| logger.info("timelinestatus: #{status.text}") }
      @client.userstream {|status| EM.next_tick { settings.sockets.each { |s| s.send(status.to_hash.to_json) } } }
    else
      @client.stop if @client
    end 
  end
  
  # Routing
  get '/' do
    # start tweetstream
    stream(run=true)
    "starta strøm"
    slim :index
  end

  put '/stop' do
    # stop tweetstream
    stream(run=false)
    "stopp saligheta!"
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
