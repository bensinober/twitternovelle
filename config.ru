log = File.new("logs/development.log", "a+") 
$stdout.reopen(log)
$stderr.reopen(log)

$stderr.sync = true
$stdout.sync = true

require File.join(File.dirname(__FILE__), 'app')
run Twitternovelle.new
