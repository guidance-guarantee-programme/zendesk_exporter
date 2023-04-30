require 'http'
require 'redis'
require_relative 'config'

class ZendeskUserRedactor
  REDIS_TICKET_ID_PAGE   = 100
  REDIS_USER_ID_SET      = 'zendesk_user_ids'.freeze
  SECONDS_IN_TWO_YEARS   = 630_720_00

  ZENDESK_API_SEARCH_URL = 'https://pensionwise.zendesk.com/api/v2/search.json'.freeze
  ZENDESK_API_DELETE_URL = 'https://pensionwise.zendesk.com/api/v2/users/destroy_many.json'.freeze

  def initialize(output: STDOUT)
    @output = output
  end

  def run
    store_user_ids_to_delete!
    delete_stored_users!
  end

  private

  attr_reader :output

  def redis
    @redis ||= Redis.new(url: ENV.fetch('REDIS_URL'), ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE })
  end

  def delete_stored_users!
    while (user_ids = pop_stored_user_ids_to_delete).any?
      puts "Deleting user IDs: #{user_ids}"

      api.delete("#{ZENDESK_API_DELETE_URL}?ids=#{user_ids.join(',')}")

      puts 'Done!'
    end
  end

  def pop_stored_user_ids_to_delete
    redis.spop(REDIS_USER_ID_SET, 100)
  end

  def store_user_ids_to_delete!
    date  = (Time.now - SECONDS_IN_TWO_YEARS).strftime('%Y-%m-%d')
    query = URI.encode("type:user created<#{date}")

    user_ids = get_users("#{ZENDESK_API_SEARCH_URL}?query=#{query}")

    redis.sadd(REDIS_USER_ID_SET, user_ids) if user_ids.any?
  end

  def api
    HTTP.auth("Basic #{ENV.fetch('ZENDESK_AUTH_TOKEN')}")
  end

  def get_users(url, user_ids = [])
    return [] unless url

    output.puts 'Getting user IDs'

    response = api.get(url).parse

    return user_ids.flatten unless response['results']

    user_ids << response['results'].map { |result| result['id'] }

    get_users(response['next_page'], user_ids)
  end
end

ZendeskUserRedactor.new.run
