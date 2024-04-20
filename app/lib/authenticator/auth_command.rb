# frozen_string_literal: true

module Unlight
  module Authenticator
    # :nodoc:
    class AuthCommand
      include Deps['jwks']

      def execute(token)
        return false if token.nil?

        JWT.decode(token, nil, true, algorithms:, jwks:)
      rescue JWT::DecodeError
        false
      end

      private

      def algorithms
        @algorithms ||= jwks.filter_map { |key| key[:alg] }.uniq
      end
    end
  end
end
