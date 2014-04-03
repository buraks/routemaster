require 'routemaster/services'
require 'routemaster/models/fifo'
require 'faraday'
require 'faraday_middleware'

# Manage delivery buffer and emitting the HTTP delivery
class Routemaster::Services::Deliver
  def initialize(queue)
    @queue  = queue
    @buffer = queue.buffer
  end

  def run
    # check if buffer full or time elapsed
    return unless _should_deliver?

    # TODO: lock the buffer for writing
    # also avoid clearing it until the acknowledgment from the callback

    # assemble data
    data = []
    events = []
    while event = @buffer.pop
      events << event
      data << {
        topic: event.topic,
        type:  event.type,
        url:   event.url,
        t:     event.timestamp
      }
    end

    # send data
    response = conn.post do |post|
      post.body = data 
    end
    return if response.success?
    
    # put events back in case of failure
    events.each { |e| @buffer.push e }
  end

  private

  def _should_deliver?
    return false if @buffer.length == 0
    return true  if @buffer.length >= @queue.max_events
    return true  if @buffer.peek.timestamp + @queue.timeout < Routemaster.now
    false
  end

  def conn
    @_conn ||= begin
      Faraday.new(@queue.callback) do |f|
        f.request :json
        f.adapter Faraday.default_adapter
      end
    end
  end
end
