require 'routemaster'
require 'sinatra'
require 'sinatra-initializers'
require 'rack/ssl'
require 'routemaster/middleware/authentication'
require 'routemaster/controllers/pulse'
require 'routemaster/controllers/topics'
require 'routemaster/controllers/health'
require 'routemaster/controllers/subscription'
require 'routemaster/mixins/log_exception'
require 'hirefire-resource' if ENV['AUTOSCALE_WITH'] == 'hirefire'

module Routemaster
  class Application < Sinatra::Base
    register Sinatra::Initializers
    include Mixins::LogException

    configure do
      # Do capture any errors. We're logging them ourselves
      set :raise_errors, false
    end

    use Rack::SSL
    use HireFire::Middleware if ENV['AUTOSCALE_WITH'] == 'hirefire'
    use Controllers::Health

    use Middleware::Authentication
    use Controllers::Pulse
    use Controllers::Topics
    use Controllers::Subscription

    not_found do
      content_type 'text/plain'
      body ''
    end

    error do
      deliver_exception env['sinatra.error']
    end
  end
end
