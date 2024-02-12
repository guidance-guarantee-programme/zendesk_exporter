require 'redis'
require 'active_support/core_ext/integer/time'
require 'active_support/core_ext/numeric/time'

require_relative 'config'

class ZendeskBackupRedactor
  def initialize(output: STDOUT)
    @output = STDOUT
  end

  def run
    keys = redis.keys('ticket:*')

    output.puts "Backup tickets total: #{keys.count}"

    keys.each_slice(50) do |batch|
      keys_to_delete = []

      batch.each do |key|
        data = redis.get(key)
        data = eval(data)

        keys_to_delete << key if Time.at(data["generated_timestamp"]) < 2.years.ago
      end

      if keys_to_delete.count > 0
        output.puts "Deleting #{keys_to_delete.count} in batch"
        redis.del(*keys_to_delete)
        output.puts "Deleted batch"
      else
        output.puts "No keys to delete in this batch"
      end
    end
  end

  private

  attr_reader :output

  def redis
    @redis ||= Redis.new(url: ENV.fetch('REDIS_URL'), ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE })
  end
end

ZendeskBackupRedactor.new.run
