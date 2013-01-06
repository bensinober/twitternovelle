require File.expand_path(File.dirname(__FILE__) + "/app")
log = File.new("logs/development.log", "a+") 
$stdout.reopen(log)
$stderr.reopen(log)

$stderr.sync = true
$stdout.sync = true
run APP
