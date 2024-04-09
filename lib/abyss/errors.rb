# frozen_string_literal: true

module Abyss
  # The base error class for Abyss
  #
  # @api public
  # @since 0.1.0
  Error = Class.new(StandardError)

  # Error raised when {Abyss::Application} fails to load
  #
  # @api public
  # @since 0.1.0
  AppLoadError = Class.new(Error)
end
