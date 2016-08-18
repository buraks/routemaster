require 'routemaster/models'
require 'routemaster/mixins/redis'
require 'routemaster/mixins/assert'
require 'routemaster/mixins/log'

module Routemaster::Models
  # An enumerable collection of Subscription
  class Subscribers
    include Routemaster::Mixins::Redis
    include Routemaster::Mixins::Assert
    include Routemaster::Mixins::Log
    include Enumerable

    def initialize(topic)
      @topic = topic
    end

    def include?(subscription)
      _redis.sismember(_key, subscription.subscriber)
    end

    def replace(subscriptions)
      new = subscriptions
      old = to_a
      (old - new).each { |sub| remove(sub) }
      (new - old).each { |sub| add(sub) }
      self
    end

    def add(subscription)
      _change(:add, subscription) do
        _log.info { "new subscriber '#{subscription.subscriber}' to '#{@topic.name}'" }
      end
    end

    def remove(subscription)
      _change(:rem, subscription) do
        _log.info { "removed subscriber '#{subscription.subscriber}' from '#{@topic.name}'" }
      end
    end


    # yields Subscriptions
    def each
      _redis.smembers(_key).each do |name|
        yield Subscription.new(subscriber: name)
      end
      self
    end

    private

    def _change(action, subscription)
      _assert subscription.kind_of?(Subscription), "#{subscription} not a Subscription"
      yield if _redis.public_send("s#{action}", _key, subscription.subscriber)
      self
    end

    def _key
      @_key ||= "subscribers:#{@topic.name}"
    end
  end
end
