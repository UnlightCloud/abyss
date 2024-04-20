# frozen_string_literal: true

module Unlight
  module API
    # :nodoc:
    module HasAuth
      def self.included(action)
        action.before :authenticate!
      end

      private

      def authenticate!(_req, _res)
        halt :unauthorized, { error: 'Unauthorized' }.to_json
      end
    end
  end
end
