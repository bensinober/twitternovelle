#encoding: UTF-8
$stdout.sync = true # gives foreman full stdout
# Script to convert twitter Atom feed to tweet hash for twitternovelle
# download tweets with: (max 100)
# http get https://search.twitter.com/search.atom q==%23nynov-filter:retweets rpp==100 src==typd rpp==100 > tweets.atom
# convert to json: 
# http://www.utilities-online.info/xmltojson/#.Uab8Ec5aUyg
require "rubygems"
require "json"
require "time"
TWEETS = File.join(File.dirname(__FILE__), 'new.json')
lost = File.join(File.dirname(__FILE__), 'lost.json')
hash = JSON.parse(IO.read(lost))
new = []
hash["feed"]["entry"].reverse.each do | jj|
  new.push({
  :created_at => DateTime.parse(jj["published"]).to_datetime,
  :text => jj["title"],
  :user => {
    :id => nil,
    :name => jj["author"]["name"],
    :screen_name => jj["author"]["uri"],
    :description => nil,
    :geo_enabled => nil,
    :statuses_count => nil,
    :lang => "no",
    :profile_image_url => jj["link"][1]["-href"]
  }, 
  :geo => nil,
  :coordinates => nil,
  :place => nil
  })
end

File.open(TWEETS, 'w') {|f| f.write(JSON.pretty_generate(JSON.parse({"tweets"=>[]}.to_json)))} unless File.exist?(TWEETS)
File.open(TWEETS, 'w') {|f| f.write(JSON.pretty_generate(JSON.parse(new.to_json)))}
