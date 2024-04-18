# frozen_string_literal: true

module Abyss
  module Api
    # The endpoint resolver
    #
    # @since 0.1.0
    class Resolver
      ACTION_KEY_NAMESPACE = 'api.actions'

      # @!attribute [r] app
      attr_reader :app

      # @param app [Abyss::Application]
      #
      # @return [Abyss::Api::Resolver]
      #
      # @since 0.1.0
      def initialize(app:)
        @app = app
      end

      def call(_path, endpoint)
        endpoint = case endpoint
                   when String then resolve(endpoint)
                   when Class
                     endpoint.respond_to?(:call) ? endpoint : endpoint.new
                   else
                     endpoint
                   end

        raise NoCallableEndpointError, "The endpoint #{endpoint} is not callable" unless endpoint.respond_to?(:call)

        endpoint
      end

      private

      def resolve(key)
        key = "#{ACTION_KEY_NAMESPACE}.#{key}"
        ensure_action_available!

        lambda do |*args|
          action = app.resolve(key) do
            raise MissingActionError, "The action #{key} is missing"
          end

          action.call(*args)
        end
      end

      def ensure_action_available!
        return if app.booted?

        raise MissingActionError, 'The application is not booted'
      end
    end
  end
end
