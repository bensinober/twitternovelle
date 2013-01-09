require 'rubygems'
require 'sinatra'

set :environment, :production
set :app_file,     'app.rb'
disable :run

log = File.new("logs/development.log", "a+") 
$stdout.reopen(log)
$stderr.reopen(log)

$stderr.sync = true
$stdout.sync = true

require File.expand_path(File.dirname(__FILE__) + "/app")
run APP
