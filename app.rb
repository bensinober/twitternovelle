#encoding: UTF-8
$stdout.sync = true # gives foreman full stdout

require "rubygems"
require "yaml"
require "bundler/setup"
require "sinatra/base"
require "sinatra-websocket"
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
  configure :development do
    require "sinatra/reloader"
    register Sinatra::Reloader
    also_reload '*.rb'
  end
  
  CONFIG = YAML::load(File.open("config/config.yml"))
  TWEETS = File.join(File.dirname(__FILE__), 'logs/', 'tweets.json')
  VAAREN = File.join(File.dirname(__FILE__), 'logs/', 'vaaren.json')
  
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
    @session[:track_terms] = ""
    
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
    
  def start_stream(track_terms=nil)
    # start userstream
    @session[:client].on_error {|error| logger.error("error: #{error.text}") }
    @session[:client].on_direct_message {|direct_message| logger.info("direct message: #{direct_message.text}") }
    #@client.on_timeline_status {|status| logger.info("timelinestatus: #{status.text}") }
    # unless session[:track_terms] is set
    if track_terms
      #split track terms or user id's by space and join as comma-separated list
      @session[:track_terms] = track_terms.split(' ').join(',')
      @session[:client].track(@session[:track_terms]) do |status| 
        EM.next_tick do
          settings.sockets.each { |s| s.send(status.to_hash.to_json) } 
          save_tweet(JSON.parse(status.to_hash.to_json))
        end
      end
    else
      #@session[:client].userstream {|status| EM.next_tick { settings.sockets.each { |s| s.send(status.to_hash.to_json) } } }
    end
    logger.info "started stream: #{@session[:client].stream.inspect}"
    @session[:client].stream
  end
  
  def save_tweet(status)
    tweet = status.to_hash.select { |k,v| ["created_at", "text", "geo", "coordinates", "place", "user"].include?(k) }
    tweet['user'] = tweet['user'].select { |k,v| ["id", "name", "screen_name", "location", "description", "geo_enabled", "statuses_count", "lang", "profile_image_url"].include?(k) }
    
    unless File.exist?(TWEETS)
      File.open(TWEETS, 'w') {|f| f.write(JSON.pretty_generate(JSON.parse({"tweets"=>[]}.to_json)))}
    end
    puts tweet
    file = JSON.parse(IO.read(TWEETS))
    file['tweets'] << tweet
    File.open(TWEETS, 'w') {|f| f.write(JSON.pretty_generate(JSON.parse(file.to_json)))}
    @session[:tweets] << tweet
  end
  #def stop_stream
  #  logger.info "stopping stream: #{@session[:client].inspect}"
  #  @session[:client].stop
  #  #@session[:client] = nil
  #end
  
  # Routes
  get '/' do
    # load from file if session restarted
    if @session[:tweets].empty? 
      hash = JSON.parse(IO.read(VAAREN))
      @session[:tweets] = hash["tweets"]
    end
    slim :index, :locals => {:websocket => CONFIG['websocket'], :track_terms => @session[:track_terms], :tweets => @session[:tweets]}
  end
  
  get '/vertical' do
    slim :vertical, :locals => {:websocket => CONFIG['websocket'], :track_terms => @session[:track_terms], :tweets => @session[:tweets]}
  end
  
  get '/tevling' do
    hash = JSON.parse(IO.read(VAAREN))
    puts hash["tweets"]
    slim :tevling, :locals => {:tweets => hash["tweets"] } 
  end
  
  post '/track' do
    if params[:track_terms]
      @session[:stream].stop if @session[:stream] # close running stream
      
      logger.info "track terms: #{params[:track_terms]}"
      @session[:track_terms] = params[:track_terms]
      @session[:stream] = start_stream(params[:track_terms])
      #slim :index, :locals => {:websocket => CONFIG['websocket'], :track_terms => @session[:track_terms], :tweets => @session[:tweets]}
      "started stream and tracking: #{@session[:track_terms]}"
    else
      "no new term sent!"
    end
  end

  get '/stop' do
    # stop tweetstream
    session[:stream].stop
    "stopp saligheita!"
  end

  get '/start' do
    # start tweetstream
    session[:stream] = start_stream
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
      
      ws.onerror do | error|
        logger.info "error: #{error}"
      end      
    end
  end
  
end
