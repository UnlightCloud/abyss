# frozen_string_literal: true

module Unlight
  module Authenticator
    # :nodoc:
    class AuthCommand
      def execute(_token)
        false
      end
    end
  end
end
