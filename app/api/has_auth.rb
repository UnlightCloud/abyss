# frozen_string_literal: true

module Unlight
  module API
    # :nodoc:
    module HasAuth
      def self.included(action)
        action.include Deps['authenticator.auth_command']
        action.before :authenticate!
      end

      private

      def authenticate!(req, _res)
        return if auth_command.execute(req.env['HTTP_AUTHORIZATION'])

        halt :unauthorized, { error: 'Unauthorized' }.to_json
      end
    end
  end
end
