require 'spec_helper'
require 'spec/support/persistence'
require 'spec/support/events'
require 'spec/support/webmock'
require 'spec/support/counters'
require 'routemaster/services/deliver'
require 'routemaster/models/subscriber'

describe Routemaster::Services::Deliver do
  let(:buffer) { Array.new }
  let(:subscriber) { Routemaster::Models::Subscriber.new(name: 'alice').save }
  let(:callback) { 'https://alice.com/widgets' }

  subject { described_class.new(subscriber, buffer) }

  before do
    WebMock.enable!
    subscriber.uuid = 'hello'
    subscriber.callback = callback
  end

  after do
    WebMock.disable!
  end

  describe '#call' do
    let(:perform) { subject.call }
    let(:callback_status) { 204 }

    before do
      @stub = stub_request(:post, callback).
        with(basic_auth: %w[hello x]).
        with { |req| @request = req }.
        to_return(status: callback_status, body: '')
    end

    shared_examples 'an event counter' do |count, tag|
      it 'increments delivery counter' do
        expect { perform rescue nil }.to change { 
          get_counter('delivery', tag.merge(queue: 'alice'))
        }.by(count)
      end
    end

    context 'when there are no events' do
      it 'passes' do
        expect { perform }.not_to raise_error
      end

      it 'POSTs to the callback' do
        perform
        expect(@stub).to have_been_requested
      end

      it_behaves_like 'an event counter', 0, status: 'success'
    end

    context 'when there are events' do
      before do
        3.times { buffer.push make_event }
      end

      it 'passes' do
        expect { perform }.not_to raise_error
      end

      it 'returns true' do
        expect(perform).to eq(true)
      end

      it 'POSTs to the callback' do
        perform
        expect(@stub).to have_been_requested
      end

      it 'sends valid JSON' do
        perform
        expect(@request.headers['Content-Type']).to eq('application/json')
        expect { JSON.parse(@request.body) }.not_to raise_error 
      end

      it 'delivers events in order' do
        perform
        events = JSON.parse(@request.body)
        expect(events.length).to eq(3)
        expect(events.first['url']).to match(/\/1$/)
        expect(events.last['url']).to match(/\/3$/)
      end

      it_behaves_like 'an event counter', 3, status: 'success'

      shared_examples 'failure' do
        it "raises a CantDeliver exception" do
          expect { perform }.to raise_error(described_class::CantDeliver)
        end

        it_behaves_like 'an event counter', 3, status: 'failure'
      end

      context 'when the callback 500s' do
        let(:callback_status) { 500 }

        it_behaves_like 'failure'
      end

      context 'when the callback cannot be resolved' do
        let(:callback) { "https://nonexistent.example.com/callback" }
        before { WebMock.disable! }

        it_behaves_like 'failure'
      end

      context 'with fake local server', slow: true do
        let(:port) { 1024 + rand(30_000) }
        let(:callback) { "https://127.0.0.1:#{port}/callback" }

        before { WebMock.disable! }

        context 'when delivery times out' do
          let(:q) { Queue.new }
          let(:listening_thread) do
            Thread.new do
              Thread.current.abort_on_exception = true
              s = TCPServer.new port
              q.push :started
              s.accept
              q.pop
              s.close
            end
          end

          before do
            listening_thread
            q.pop # wait for server to start
          end

          after do
            q.push :done
            listening_thread.join # wait for server to complete
          end

          it_behaves_like 'failure'
        end

        context 'when connection fails' do
          # no server thread started here
          it_behaves_like 'failure'
        end
      end
    end

  end
end
