# frozen_string_literal: true

module Abyss
  # Provides the API server support
  #
  # @since 0.1.0
  module Api
    # @api private
    ROUTES_PATH = 'config/routes.rb'
    private_constant :ROUTES_PATH

    # @api private
    ROUTES_CLASS_NAME = 'Routes'
    private_constant :ROUTES_CLASS_NAME

    # Raised when an endpoint is not callable
    #
    # @api public
    # @since 0.1.0
    NoCallableEndpointError = Class.new(Error)

    # Raised when an action is missing
    #
    # @api public
    # @since 0.1.0
    MissingActionError = Class.new(Error)

    module_function

    def routes
      @routes ||= load_routes # rubocop:disable ThreadSafety/InstanceVariableInClassMethod
    end

    def resolver
      @resolver ||= Resolver.new(app: Abyss.app) # rubocop:disable ThreadSafety/InstanceVariableInClassMethod
    end

    # The API server
    def app
      @app ||= Router.new(routes:, resolver:) # rubocop:disable ThreadSafety/InstanceVariableInClassMethod
    end

    # Rack application
    #
    # @since 0.1.0
    def call(env)
      app.call(env)
    end

    # @api private
    def load_routes
      routes_path = File.join(Abyss.root, ROUTES_PATH)

      begin
        require routes_path
      rescue LoadError => e
        raise e unless e.path == routes_path
      end

      begin
        namespace = Abyss.app.app_name.namespace
        namespace.const_get(ROUTES_CLASS_NAME).routes
      rescue NameError => e
        raise e unless e.name == ROUTES_CLASS_NAME.to_sym
      end
    end
  end
end
