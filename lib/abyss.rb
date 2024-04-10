# frozen_string_literal: true

require 'zeitwerk'

require_relative 'abyss/constants'

# Abyss is open-source Unlight server
#
# @since 0.1.0
module Abyss
  @_mutex = Mutex.new

  module_function

  # @api private
  #
  # @since 0.1.0
  def loader
    @loader ||= Zeitwerk::Loader.for_gem.tap do |loader| # rubocop:disable ThreadSafety/InstanceVariableInClassMethod
      loader.ignore("#{__dir__}/dawn.rb")
      loader.ignore("#{__dir__}/{dawn,ruby_inline,tasks}/")
      loader.ignore("#{__dir__}/abyss/{constants,errors,setup}.rb")
    end
  end

  # @return [Pathname] project root
  #
  # @since 0.1.0
  def root
    Bundler.root
  end

  # @return [Abyss::App] the application class
  #
  # @since 0.1.0
  def app
    @_mutex.synchronize do
      raise AppLoadError, 'Abyss.app is not configured' unless defined?(@app)

      @app
    end
  end

  # @api private
  # @since 0.1.0
  def app=(app)
    @_mutex.synchronize do
      raise AppLoadError, 'Abyss.app is already configured' if app?

      @app = app
    end
  end

  # @api private
  # @since 0.1.0
  def app?
    instance_variable_defined?(:@app)
  end

  # @api public
  # @since 0.1.0
  def env(env: ENV)
    env.fetch('ABYSS_ENV') { env.fetch('DAWN_ENV', 'development') }.to_sym
  end

  # @api public
  # @since 0.1.0
  def env?(*names)
    names.map(&:to_sym).include?(env)
  end

  # Boots the application
  #
  # @see Application::ClassMethods#boot
  #
  # @api public
  # @since 0.1.0
  def boot
    app.boot
  end

  # Return application's logger
  #
  # @return [logger] the application logger
  #
  # @since 0.1.0
  def logger
    app[:logger]
  end

  # Finds and loads the Abyss application file (`config/application.rb`)
  #
  # @return [Abyss::App] the loaded application
  #
  # @since 0.1.0
  def setup
    return app if app?

    raise AppLoadError, 'Abyss application file is missing' unless app_path.exist?

    require app_path(root)
    app
  end

  # Find and returns the absolute path for Abyss application file (`config/application.rb`)
  #
  # @param [Pathname, String] root the project root
  #
  # @return [Pathname, nil] the absolute path for Abyss application file
  #
  # @since 0.1.0
  def app_path(root = Dir.pwd)
    dir = Pathname.new(root)
    path = dir.join(APP_PATH)

    return path if path.file?
    return app_path(dir.parent) unless dir.root?

    nil
  end

  loader.setup

  require_relative 'abyss/errors'
end
