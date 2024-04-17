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

    module_function

    def routes
      @routes ||= load_routes # rubocop:disable ThreadSafety/InstanceVariableInClassMethod
    end

    # The API server
    def app
      @app ||= Router.new(routes:) # rubocop:disable ThreadSafety/InstanceVariableInClassMethod
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
