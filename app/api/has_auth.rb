# frozen_string_literal: true

module Unlight
  module API
    # :nodoc:
    module HasAuth
      AUTHORIZATION_PATTERN = /^Bearer (?<token>.+)$/

      def self.included(action)
        action.include Deps['authenticator.auth_command']
        action.before :authenticate!
      end

      private

      def authenticate!(req, _res)
        token = req.env['Authorization']&.match(AUTHORIZATION_PATTERN)&.[](:token)
        return if auth_command.execute(token)

        halt :unauthorized, { error: 'Unauthorized' }.to_json
      end
    end
  end
end
