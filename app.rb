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
  TRE    = JSON.parse(IO.read(File.join(File.dirname(__FILE__), 'logs/', 'tre.json') ))
  VAAREN = JSON.parse(IO.read(File.join(File.dirname(__FILE__), 'logs/', 'vaaren.json') ))
  LYST   = JSON.parse(IO.read(File.join(File.dirname(__FILE__), 'logs/', 'lyst.json') ))
  
  THEMES = [:våren, :lyst, :tre]
  ALL_TWEETS = { :våren => VAAREN["tweets"], :lyst => LYST["tweets"], :tre => TRE["tweets"] }
  
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
    # default track terms
    @session[:track_terms] = "#nynov"
    @session[:tweets]      = []

#=begin
    # only used in contest
    @session[:contest] = true
    # create tweet file if not exists
    File.open(TWEETS, 'w') {|f| f.write(JSON.pretty_generate(JSON.parse({"tweets"=>[]}.to_json)))} unless File.exist?(TWEETS)
    
    # load tweets from file if session restarted
    hash = JSON.parse(IO.read(TWEETS))
    hash["tweets"].each {|tweet| @session[:tweets] << tweet }

    # open Twitter client connection
    @session[:client] = TweetStream::Client.new
    #@session[:client].on_inited { @session[:stream] = start_stream(@session[:track_terms]) }
#=end
=begin
    #random tweet every 5 secs
    EM::next_tick do
      EM::add_periodic_timer(30) do
        self.settings.sockets.each do |s|
          s.send(self.random_tweet.to_json)
        end
      end
    end
=end
  end
    
  def start_stream(track_terms=nil)
    # start userstream
    @session[:client].on_error {|error| logger.error("error: #{error.text}") }
    @session[:client].on_reconnect {|timeout, retries| logger.error("reconnect error: timeout: #{timeout}, retries: #{retries}") }
    #@session[:client].on_direct_message {|direct_message| logger.info("direct message: #{direct_message.text}") }
    #@client.on_timeline_status {|status| logger.info("timelinestatus: #{status.text}") }
    # unless session[:track_terms] is set
    if track_terms
      #split track terms or user id's by space and join as comma-separated list
      @session[:track_terms] = track_terms.split(' ').join(',')
      @session[:client].track(@session[:track_terms]) do |status| 
        EM.next_tick do
          unless status.to_hash[:text] =~ /^RT/ or status.to_hash[:text] =~ /^\@/ # filter out retweets 
            settings.sockets.each { |s| s.send(status.to_hash.to_json) }
            save_tweet(JSON.parse(status.to_hash.to_json))
          end
        end
      end
    else
      #show userstream
      #@session[:client].userstream {|status| EM.next_tick { settings.sockets.each { |s| s.send(status.to_hash.to_json) } } }
    end
    logger.info "started stream: #{@session[:client].stream.inspect}"
    @session[:client].stream
  end
  
  def save_tweet(status)
    tweet = status.to_hash.select { |k,v| ["created_at", "text", "geo", "coordinates", "place", "user"].include?(k) }
    tweet['user'] = tweet['user'].select { |k,v| ["id", "name", "screen_name", "location", "description", "geo_enabled", "statuses_count", "lang", "profile_image_url"].include?(k) }
    
    puts tweet
    file = JSON.parse(IO.read(TWEETS))
    file['tweets'] << tweet
    File.open(TWEETS, 'w') {|f| f.write(JSON.pretty_generate(JSON.parse(file.to_json)))}
    @session[:tweets] << tweet
  end

  def random_tweet
    theme = THEMES.sample
    sample = { theme => ALL_TWEETS[theme].sample }
  end
  
  # Routes
  get '/' do
    # present contest or intermission based on @session[:contest] switch
    @session[:contest] ?
      slim(:index, :locals => {:websocket => CONFIG['websocket'], :track_terms => @session[:track_terms], :tweets => @session[:tweets]}) :
      slim(:intermission, :locals => {:websocket => CONFIG['websocket']})
  end
  
  get '/vertical' do
    # present contest or intermission based on @session[:contest] switch
    @session[:contest] ?
      slim(:vertical, :locals => {:websocket => CONFIG['websocket'], :track_terms => @session[:track_terms], :tweets => @session[:tweets]}) :
      slim(:intermission, :locals => {:websocket => CONFIG['websocket']})
  end
  
  get '/tevling' do
    #puts hash["tweets"]
    slim :tevling, :locals => {:tweets => TRE["tweets"] } 
  end
  
  # POST / PUT
  post '/track' do
    # restart stream with new track terms
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

  put '/stop' do
    # stop tweetstream
    @session[:stream].stop
    "stoppa saligheita!"
  end

  put '/start' do
    # start tweetstream
    @session[:stream] = start_stream(@session[:track_terms])
    "starta saligheita!"
  end

  put '/intermission' do
    # contest/intermission toggle
    @session[:contest] ? @session[:contest] = false : @session[:contest] = true
    if @session[:contest]
      "contest started"
    else
      "contest stopped - intermission started"
    end
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
