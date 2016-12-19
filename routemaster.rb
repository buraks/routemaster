module Routemaster
  def self.now
    (Time.now.utc.to_f * 1e3).to_i
  end

  def self.batch_queue
    @batch_queue ||= begin
      require 'routemaster/models/queue'
      Models::Queue.new(name: 'main')
    end
  end
end
