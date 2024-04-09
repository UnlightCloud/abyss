# frozen_string_literal: true

require 'zeitwerk'

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
      raise 'Abyss.app is not configured' unless defined?(@app)

      @app
    end
  end

  # @api private
  # @since 0.1.0
  def app=(app)
    @_mutex.synchronize do
      raise 'Abyss.app is already configured' if instance_variable_defined?(:@app)

      @app = app
    end
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

  loader.setup
end
