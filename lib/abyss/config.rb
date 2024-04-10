# frozen_string_literal: true

require 'dry/configurable'
require 'dry/inflector'

module Abyss
  # Abyss application configuration
  #
  # @since 0.1.0
  class Config
    include Dry::Configurable

    # @!attribute [rw] inflector
    #
    # @return [Dry::Inflector]
    #
    # @api public
    # @since 0.1.0
    setting :inflector, default: Dry::Inflector.new

    # Return the application's {Abyss::AppName app_name}
    #
    # @return [Abyss::AppName]
    #
    # @api private
    # @since 0.1.0
    attr_reader :app_name

    # Return the application env
    #
    # @return [Symbol]
    #
    # @api private
    # @since 0.1.0
    attr_reader :env

    # @api private
    #
    # @param [Abyss::AppName] app_name
    # @param [Symbol] env
    #
    # @return [self]
    # @since 0.1.0
    def initialize(app_name:, env:)
      @app_name = app_name
      @env = env
    end

    private

    def method_missing(method, *, &)
      return super unless config.respond_to?(method)

      config.public_send(method, *, &)
    end

    def respond_to_missing?(method, *)
      config.respond_to?(method) || super
    end
  end
end
