# frozen_string_literal: true

require 'forwardable'

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
      extend Forwardable

      delegate %i[
        register
        register_provider
        start
        stop
        key?
        keys
        []
        resolve
      ] => :container

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

      # return the application's root path
      #
      # @return [Pathname]
      #
      # @since 0.1.0
      def root
        @root ||= Pathname.new(Abyss.root)
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

      # return the application's settings
      #
      # @return [Abyss::Settings]
      #
      # @since 0.1.0
      def settings
        return @settings if instance_variable_defined?(:@settings)

        @settings = Settings.load(self)
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
      def prepare(provider_name = nil)
        if provider_name
          container.prepare(provider_name)
        else
          prepare_app
        end

        self
      end

      private

      # @api private
      # @since 0.1.0
      def prepare_app
        return self if prepared?

        config.finalize!

        prepare_settings
        prepare_container_constants
        prepare_container_plugins
        prepare_container_base_config
        prepare_app_component_dirs

        container.configured!

        prepare_autoloader

        @prepared = true

        self
      end

      # @api private
      # @since 0.1.0
      def prepare_settings
        container.register(:settings, settings) if settings
      end

      # @api private
      # @since 0.1.0
      def prepare_container_constants
        namespace.const_set(:Container, container)
        namespace.const_set(:Deps, container.injector)
      end

      # @api private
      # @since 0.1.0
      def prepare_container_plugins
        container.use(:env, inferrer: -> { Abyss.env })
        container.use(
          :zeitwerk,
          loader: autoloader,
          run_setup: false,
          eager_load: false
        )
      end

      # @api private
      # @since 0.1.0
      def prepare_container_base_config
        container.config.name = app_name.to_sym
        container.config.root = root
        container.config.provider_dirs = [File.join('config', 'providers')]
        container.config.registrations_dir = File.join('config', 'registrations')

        container.config.env = config.env
        container.config.inflector = config.inflector
      end

      # @api private
      # @since 0.1.0
      def prepare_autoloader
        autoloader.ignore(root.join(CONFIG_DIR)) if root.join(CONFIG_DIR)&.directory?

        autoloader.setup
      end

      # @api private
      # @since 0.1.0
      def prepare_app_component_dirs
        return unless root.join(APP_DIR).directory?

        container.config.component_dirs.add(APP_DIR) do |dir|
          dir.namespace.add_root(key: nil, const: app_name.name)
        end
      end
    end
  end
end
# rubocop:enable ThreadSafety/InstanceVariableInClassMethod
