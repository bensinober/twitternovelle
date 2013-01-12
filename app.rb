#encoding: UTF-8
$stdout.sync = true # gives foreman full stdout

require "rubygems"
require "bundler/setup"
require "sinatra/base"
require "sinatra-websocket"
#require "sinatra/reloader"
require "slim"
require "yajl"
require "yajl/json_gem"
require "logger"
require "tweetstream"

class Twitternovelle < Sinatra::Base

  # Sinatra configs
  set :static, true
  set :root, File.dirname(__FILE__)
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
    
  def initialize
    super
    @session = {}
    # to be used later for logging
    @session[:tweets] = []
    
    # open Twitter client connection
    @session[:client] = TweetStream::Client.new
    #ping testing...
    #EM::next_tick do
    #  EM::add_periodic_timer(1) do
    #    self.settings.sockets.each do |s|
    #      s.send("test</br>")
    #    end
    #  end
    #end
  end
    
  def start_stream
    # start userstream
    @session[:client].on_error {|error| logger.error("error: #{error.text}") }
    @session[:client].on_direct_message {|direct_message| logger.info("direct message: #{direct_message.text}") }
    #@client.on_timeline_status {|status| logger.info("timelinestatus: #{status.text}") }
    @session[:client].userstream {|status| EM.next_tick { settings.sockets.each { |s| s.send(status.to_hash.to_json) } } }
    logger.info "started stream: #{@session[:client]}"
  end
  
  def stop_stream
    logger.info "stopping stream: #{@session[:client]}"
    @session[:client].stop
    @session[:client] = nil
  end
  
  # Routes
  get '/' do
    slim :index, :locals => {:websocket => CONFIG['websocket']}
  end

  get '/stop' do
    # stop tweetstream
    stop_stream
    "stopp saligheita!"
  end

  get '/start' do
    # start tweetstream
    start_stream
    "start saligheita!"
  end
  
  # sinatra websocket server
  get '/ws' do
    return false unless request.websocket?
  
    request.websocket do |ws|
  
      ws.onopen do
        #ws.send("Hello World!")
        settings.sockets << ws
        logger.info "connected from: #{ws.request['host']}"
      end
  
      ws.onmessage do |msg|
        logger.info "Message from browser client #{msg} -"
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
