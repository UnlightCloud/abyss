# frozen_string_literal: true

require 'rack/test'

# :nodoc:
module ApiTest
  include Rack::Test::Methods

  def app
    Abyss::Api
  end
end

World(ApiTest)
