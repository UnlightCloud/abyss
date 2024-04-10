# frozen_string_literal: true

require 'dry/system'
require 'dry/inflector'

# rubocop:disable ThreadSafety/InstanceVariableInClassMethod
module Abyss
  # @since 0.1.0
  class Application
    @_mutex = Mutex.new

    class << self
      def inherited(subclass)
        super

        Abyss.app = subclass

        subclass.extend(ClassMethods)

        @_mutex.synchronize do
          subclass.class_eval do
            @autoloader = Zeitwerk::Loader.new
            @container = Class.new(Dry::System::Container)
            @config = Config.new(app_name:, env: Abyss.env)
          end
        end
      end
    end

    # Class methods defined on the application
    #
    # @since 0.1.0
    module ClassMethods
      # return application config
      #
      # @return [Abyss::Config]
      #
      # @since 0.1.0
      attr_reader :config

      # return abyss autoloader
      #
      # @return [Zeitwrk::Loader]
      #
      # @since 0.1.0
      attr_reader :autoloader

      # return abyss container
      #
      # @return [Dry::System::Container]
      #
      # @since 0.1.0
      attr_reader :container

      # return a {AppName} for the application, an object with methods in various format
      #
      # @return [AppName]
      #
      # @since 0.1.0
      def app_name
        @app_name ||= AppName.new(self, inflector: method(:inflector))
      end

      # return the inflector
      #
      # @return [Dry::Inflector]
      #
      # @since 0.1.0
      def inflector
        config.inflector
      end

      # return the application namespace
      #
      # @return [Module]
      #
      # @since 0.1.0
      def namespace
        app_name.namespace
      end

      # return is booted
      #
      # @return [Boolean]
      #
      # @since 0.1.0
      def booted?
        !!@booted
      end

      # boot the application
      #
      # @return [self]
      #
      # @since 0.1.0
      def boot
        return self if booted?

        prepare

        container.finalize!
        @booted = true

        self
      end

      # return is prepared
      #
      # @return [Boolean]
      #
      # @since 0.1.0
      def prepared?
        !!@prepared
      end

      # prepare the application
      #
      # @return [self]
      #
      # @since 0.1.0
      def prepare
        return self if prepared?

        config.finalize!

        namespace.const_set(:Container, container)
        namespace.const_set(:Deps, container.injector)

        @prepared = true

        self
      end
    end
  end
end
# rubocop:enable ThreadSafety/InstanceVariableInClassMethod
