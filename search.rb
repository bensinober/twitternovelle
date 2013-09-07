#encoding: UTF-8
#!/usr/bin/env ruby
require 'rubygems'
require 'yaml'
require 'twitter'
require 'json'

CONFIG = YAML::load(File.open("config/config.yml"))

Twitter.configure do |config|
  config.consumer_key = CONFIG['twitter']['consumer_key']
  config.consumer_secret = CONFIG['twitter']['consumer_secret']
  config.oauth_token = CONFIG['twitter']['oauth_token']
  config.oauth_token_secret = CONFIG['twitter']['oauth_token_secret']
end
=begin 
client = Twitter::Client.new(
  :consumer_key => CONFIG['twitter']['consumer_key'],
  :consumer_secret => CONFIG['twitter']['consumer_secret'],
  :access_token => CONFIG['twitter']['oauth_token'],
  :access_token_secret => CONFIG['twitter']['oauth_token_secret']
)
=end
#OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

SEARCH = File.join(File.dirname(__FILE__), 'logs/', 'search.json')
File.open(SEARCH, 'w') {|f| f.write(JSON.pretty_generate(JSON.parse({"tweets"=>[]}.to_json)))} unless File.exist?(SEARCH)

tweets = []

Twitter.search("#nynov", :count => 50, :result_type => "recent").results.reverse.map do |tweet|
  unless tweet.to_hash[:text] =~ /^RT/ or tweet.to_hash[:text] =~ /^\@/ # filter out retweets 
    tw = tweet.to_hash.select { |k,v| [:created_at, :text, :geo, :coordinates, :place, :user].include?(k) }
    tw[:user] = tw[:user].select { |k,v| [:id, :name, :screen_name, :location, :description, :geo_enabled, :statuses_count, :lang, :profile_image_url].include?(k) }
    tweets << tw
    puts tweet.to_hash
  end
end

file = JSON.parse(IO.read(SEARCH))
tweets.each {|tweet| file['tweets'] << tweet } 
File.open(SEARCH, 'w') {|f| f.write(JSON.pretty_generate(JSON.parse(file.to_json)))}

#puts "Saved " + tweets['tweets'].count.to_s + "tweets to #{SEARCH}"
