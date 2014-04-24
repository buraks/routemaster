require 'spec_helper'
require 'routemaster/services/pulse'

describe Routemaster::Services::Pulse do
  describe '#run' do
    let(:perform) { subject.run }

    it 'returns true' do
      expect(perform).to be_true
    end

    context 'when Redis is down' do
      before { Redis.any_instance.stub(:ping).and_raise(Redis::CannotConnectError) }

      it 'returns false' do
        expect(perform).to be_false
      end
    end

    context 'when RabbitMQ is down' do
      before { subject.stub(:bunny).and_raise(Bunny::TCPConnectionFailed.new(1,2,3)) }

      it 'returns false' do
        expect(perform).to be_false
      end
    end
  end
end
