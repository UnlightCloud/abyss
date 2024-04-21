# frozen_string_literal: true

require 'rack/test'

# :nodoc:
module ApiTest
  include Rack::Test::Methods

  def app
    Abyss::Api
  end

  def api_key
    @api_key ||= OpenSSL::PKey::RSA.new(2048)
  end

  def api_jwk
    @api_jwk ||= JWT::JWK.new(api_key, { use: 'sig', alg: 'RS512', kid: 'test' })
  end
end

World(ApiTest)

Before do
  Unlight::Container.stub(:jwks, JWT::JWK::Set.new(api_jwk))
end
