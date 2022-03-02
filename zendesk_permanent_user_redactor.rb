require 'http'
require 'redis'
require_relative 'config'

class ZendeskPermanentUserRedactor
  REDIS_DELETED_USER_IDS_SET    = 'zendesk_deleted_user_ids'.freeze
  ZENDESK_API_DELETED_USERS_URL = 'https://pensionwise.zendesk.com/api/v2/deleted_users'.freeze

  def initialize(output: STDOUT)
    @output = output
  end

  def run
    #store_user_ids_to_delete!

    delete_stored_users!
  end

  private

  attr_reader :output

  def redis
    @redis ||= Redis.new(url: ENV.fetch('REDIS_URL'))
  end

  def delete_stored_users!
    pop_stored_user_ids_to_delete.each do |user_id|
      output.puts "Deleting #{user_id}"

      api.delete("#{ZENDESK_API_DELETED_USERS_URL}/#{user_id}")
    end
  end

  def pop_stored_user_ids_to_delete
    # only pop 700 each time as the API is rate limited to 700 per 10 mins
    # and in the production environment we can just simply run this every 10
    # minutes as a cheap workaround
    redis.spop(REDIS_DELETED_USER_IDS_SET, 700)
  end

  def store_user_ids_to_delete!
    user_ids = get_users("#{ZENDESK_API_DELETED_USERS_URL}.json")

    redis.sadd(REDIS_DELETED_USER_IDS_SET, user_ids) if user_ids.any?
  end

  def api
    HTTP.auth("Basic #{ENV.fetch('ZENDESK_AUTH_TOKEN')}")
  end

  def get_users(url, user_ids = [])
    return [] unless url

    output.puts 'Getting user IDs'

    response = api.get(url).parse

    return user_ids.flatten unless response['deleted_users']

    user_ids << response['deleted_users']
                .reject { |result| result['name'] == 'Permanently Deleted User' }
                .map { |result| result['id'] }

    output.puts response['next_page']
    get_users(response['next_page'], user_ids)
  end
end

ZendeskPermanentUserRedactor.new.run
