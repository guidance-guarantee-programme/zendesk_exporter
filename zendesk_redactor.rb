require 'http'
require 'redis'
require_relative 'config'

class ZendeskRedactor
  REDIS_TICKET_ID_SET    = 'zendesk_ticket_ids'.freeze
  SECONDS_IN_TWO_YEARS   = 630_720_00

  ZENDESK_API_SEARCH_URL = 'https://pensionwise.zendesk.com/api/v2/search.json'.freeze
  ZENDESK_API_DELETE_URL = 'https://pensionwise.zendesk.com/api/v2/tickets/destroy_many.json'.freeze

  def initialize(output: STDOUT)
    @output = output
  end

  def run
    store_ticket_ids_to_delete!
    delete_stored_tickets!
  end

  private

  attr_reader :output

  def redis
    @redis ||= Redis.new(url: ENV.fetch('REDIS_URL'))
  end

  def delete_stored_tickets!
    while (ticket_ids = pop_stored_ticket_ids_to_delete).any?
      puts "Deleting ticket IDs: #{ticket_ids}"

      api.delete("#{ZENDESK_API_DELETE_URL}?ids=#{ticket_ids.join(',')}")

      puts 'Done!'
    end
  end

  def pop_stored_ticket_ids_to_delete
    redis.spop(REDIS_TICKET_ID_SET, 100)
  end

  def store_ticket_ids_to_delete!
    date  = (Time.now - SECONDS_IN_TWO_YEARS).strftime('%Y-%m-%d')
    query = URI.encode("type:ticket created<#{date}")

    ticket_ids = get_tickets("#{ZENDESK_API_SEARCH_URL}?query=#{query}")

    redis.sadd(REDIS_TICKET_ID_SET, ticket_ids) if ticket_ids.any?
  end

  def api
    HTTP.auth("Basic #{ENV.fetch('ZENDESK_AUTH_TOKEN')}")
  end

  def get_tickets(url, ticket_ids = [])
    return [] unless url

    output.puts 'Getting ticket IDs'

    response = api.get(url).parse

    return ticket_ids.flatten unless response['results']

    ticket_ids << response['results'].map { |result| result['id'] }

    get_tickets(response['next_page'], ticket_ids)
  end
end

ZendeskRedactor.new.run
