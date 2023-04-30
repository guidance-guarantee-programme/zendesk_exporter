require 'redis'
require 'sinatra'

get '/' do
  r = Redis.new(url: ENV.fetch('REDIS_URL'), ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE })

  if t = r.get('latest_ticket_start_time')
    "<h1>Latest ticket start time: #{Time.at(t.to_i)}</h1>"
  else
    'No latest ticket start time yet!'
  end
end
