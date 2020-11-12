require 'bugsnag'

Bugsnag.configure do |config|
  config.api_key = ENV['BUGSNAG_API_KEY']
end

at_exit do
  Bugsnag.notify($ERROR_INFO) if $ERROR_INFO
end
