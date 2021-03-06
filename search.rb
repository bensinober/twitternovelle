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

SEARCH = File.join(File.dirname(__FILE__), 'logs/', 'search.json')
File.open(SEARCH, 'w') {|f| f.write(JSON.pretty_generate(JSON.parse({"tweets"=>[]}.to_json)))} unless File.exist?(SEARCH)
file = JSON.parse(IO.read(SEARCH))

count = 0
tweets = []

Twitter.search("#nynov", :count => 20, :result_type => "recent").results.reverse.map do |tweet|
  unless tweet.to_hash[:text] =~ /^RT/ # filter out retweets
    unless file['tweets'].any? { |oldtweet| oldtweet["id_str"] == tweet.to_hash[:id_str] } # don't save if already there
      tw = tweet.to_hash.select { |k,v| [:id_str, :created_at, :text, :geo, :coordinates, :place, :user].include?(k) }
      tw[:user] = tw[:user].select { |k,v| [:id, :name, :screen_name, :location, :description, :geo_enabled, :statuses_count, :lang, :profile_image_url].include?(k) }
      tweets << tw
      count +=1
      puts tweet.to_hash
    end
  end
end


tweets.each {|tweet| file['tweets'] << tweet } 
File.open(SEARCH, 'w') {|f| f.write(JSON.pretty_generate(JSON.parse(file.to_json)))}

puts "Saved #{count.to_s} tweets to #{SEARCH}"
