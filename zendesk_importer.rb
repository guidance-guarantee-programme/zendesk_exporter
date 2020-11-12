require 'http'
require 'redis'
require_relative 'config'

class ZendeskImporter
  ZENDESK_API_URL = 'https://pensionwise.zendesk.com/api/v2/incremental/tickets.json'

  def initialize(output: STDOUT)
    @output = STDOUT
  end

  def run
    tickets = new_tickets

    output.puts "Ticket total: #{tickets.count}"

    tickets.each do |ticket|
      redis.multi do
        redis.set("ticket:#{ticket['id']}", ticket)
        redis.set("latest_ticket_start_time", ticket['generated_timestamp'])
      end
    end

    output.puts "Done!"
  end

  private

  attr_reader :output

  def redis
    @redis ||= Redis.new(url: ENV.fetch('REDIS_URL'))
  end

  def new_tickets
    get_tickets("#{ZENDESK_API_URL}?start_time=#{latest_ticket_start_time}&includes=users,comments")
  end

  def latest_ticket_start_time
    redis.get('latest_ticket_start_time') || Time.parse('2019-07-01').to_i
  end

  def api
    HTTP.auth("Basic #{ENV.fetch('ZENDESK_AUTH_TOKEN')}")
  end

  def get_tickets(url, tickets = [])
    output.puts "Getting tickets "

    response = api.get(url).parse

    tickets << response['tickets']

    return tickets.flatten if response['end_of_stream']

    get_tickets(response['next_page'], tickets)
  end
end

ZendeskImporter.new.run
