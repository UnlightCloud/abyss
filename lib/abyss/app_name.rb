# frozen_string_literal: true

require_relative 'constants'

module Abyss
  # Represents the application name
  #
  # @since 0.1.0
  class AppName
    # return a new AppName for the application
    #
    # @param [Class] application
    # @param [Proc] inflector
    #
    # @since 0.1.0
    def initialize(application, inflector:)
      @application = application
      @inflector = inflector
    end

    # return the application name as downcased and underscored string
    #
    # @return [String]
    #
    # @since 0.1.0
    def name
      inflector.underscore(namespace_name)
    end

    alias path name
    alias to_s name

    # return the namespace name of the application's module namespace
    #
    # @return [String]
    #
    # @since 0.1.0
    def namespace_name
      app_name.split(MODULE_DELIMITER)[0..-2].join(MODULE_DELIMITER)
    end

    # return the namespace constant of the application's module namespace
    #
    # @return [Module]
    #
    # @since 0.1.0
    def namespace_constant
      inflector.constantize(namespace_name)
    end

    alias namespace namespace_constant

    # return the application name symbolized
    #
    # @return [Symbol]
    #
    # @since 0.1.0
    def to_sym
      name.to_sym
    end

    private

    def app_name
      @application.name
    end

    def inflector
      @inflector.call
    end
  end
end
