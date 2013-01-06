#encoding: UTF-8
require "rubygems"
require "bundler/setup"
require "sinatra"
require "sinatra-websocket"
require "sinatra/reloader" if development?
require "slim"
require "json"
require "logger"
require "tweetstream"

class APP < Sinatra::Base
  
  # Sinatra configs
  session = {}
  set :server, 'thin'
  set :sockets, []
  
  # Routing
  get '/' do
    session[:history] = []
    # Nysgjerrig på boka?
    logger.info("Sesjon - -")
    slim(:index)
  end
  
  get '/ws' do
    # handles the messages from the RFID-reader
    return false unless request.websocket?
  
    request.websocket do |ws|
  
      ws.onopen do
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
