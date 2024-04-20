# frozen_string_literal: true

Abyss.app.register_provider :jwks do
  prepare do
    require 'jwt'
    require 'json'
  end

  start do
    settings = target[:settings]
    jwks = JSON.parse(settings[:jwks] || '{}')

    register :jwks, JWT::JWK::Set.new(jwks)
  end
end
