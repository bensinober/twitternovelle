#encoding: UTF-8
$stdout.sync = true # gives foreman full stdout

require "rubygems"
require "bundler/setup"
require "sinatra/base"
require "sinatra-websocket"
#require "sinatra/reloader"
#require "em-http-request"
require "slim"
require "yajl"
require "yajl/json_gem"
require "logger"
require "tweetstream"

class Twitternovelle < Sinatra::Base

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
      # start userstream
      @client.userstream {|status| EM.next_tick { settings.sockets.each { |s| s.send(status.to_hash.to_json) } } }
    else
      @client.stop if @client
    end 
  end
  
  # Routing
  get '/' do
    # start tweetstream
    stream(run=true)
    "startet strøm"
    slim :index, :locals => {:websocket => CONFIG['websocket']}
  end

  put '/stop' do
    # stop tweetstream
    stream(run=false)
    "stopp saligheta!"
  end

  get '/ws' do
    return false unless request.websocket?
  
    request.websocket do |ws|
  
      ws.onopen do
        #ws.send("Hello World!")
        settings.sockets << ws
        logger.info "connected from: #{ws.request['host']}"
      end
  
      ws.onmessage do |msg|
        logger.info "Broadcasting Tweet #{msg} -"
        EM.next_tick { settings.sockets.each{|s| s.send(msg) } }
      end
  
      ws.onclose do
        #warn("websocket closed")
        settings.sockets.delete(ws)
        logger.info "disconnected from: #{ws.request['host']}"
      end
    end
  end
  
end
