require 'rubygems'
require 'sinatra'

Sinatra::Application.default_options.merge!(
  :run => false,
  :env => :production
)

log = File.new("logs/development.log", "a+") 
$stdout.reopen(log)
$stderr.reopen(log)

$stderr.sync = true
$stdout.sync = true

require File.expand_path(File.dirname(__FILE__) + "/app")
run APP
