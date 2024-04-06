# frozen_string_literal: true

require 'singleton'
require 'forwardable'

module Abyss
  # Maintenance mode management
  #
  # @since 0.1.0
  class Maintenance
    class << self
      extend Forwardable

      delegate %i[enabled? enable disable] => :instance
    end

    include Singleton

    FEATURE_KEY = 'maintenance'
    FEATURE_VALUE = 'yes'

    def initialize
      @cache = Abyss::Cache.current
    end

    # Check if maintenance mode is enabled
    #
    # @return [Boolean]
    #
    # @since 0.1.0
    def enabled?
      @cache.get(FEATURE_KEY) == FEATURE_VALUE
    end

    # Enable maintenance mode
    #
    # @return [Boolean]
    #
    # @since 0.1.0
    def enable
      @cache.set(FEATURE_KEY, FEATURE_VALUE)
    end

    # Disable maintenance mode
    #
    # @return [Boolean]
    #
    # @since 0.1.0
    def disable
      @cache.delete(FEATURE_KEY)
    end
  end
end
