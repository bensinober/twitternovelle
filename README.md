# Simple Twitter Streaming Novel

    A small webapp to stream live twitter feed
    
## Requirements

Needs a working Ruby environment with bundler gem installed. 
Preferrably installed via Ruby Version Manager on https://rvm.io/rvm/install/
Install builder gem afterwards:

    gem install bundler
    
Also needs a working twitter account with developer API enabled. Login via `https://dev.twitter.com/docs/streaming-apis` 
to create key/secrets.
    
## Installation

copy `conf/example.config.yml` to `conf/config.yml` and edit to fit twitter account 

    bundle
    rackup
    
now point your browser to host:port defined in `config.yml`    

## How it works

The webapp uses sinatra-websockets and tweetstream with Eventmachine under the hood.

Tweetstream runs an Eventmachine stream that polls Twitter by defined userstream or hashtag/search.
On a new event it sends a message to a sinatra websocket, which forwards it to browser's javascript websocket.
Javascript then appends the tweet table in browser.
