# frozen_string_literal: true

module Abyss
  # Provides the API server support
  #
  # @since 0.1.0
  module Api
    module_function

    # The API server
    def app
      @app ||= Router.new(routes: Routes::Builder.empty) # rubocop:disable ThreadSafety/InstanceVariableInClassMethod
    end

    # Rack application
    #
    # @since 0.1.0
    def call(env)
      app.call(env)
    end
  end
end
