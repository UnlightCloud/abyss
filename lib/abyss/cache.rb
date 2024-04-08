# frozen_string_literal: true

require 'singleton'
require 'forwardable'

require 'dalli'

module Abyss
  # The cache server adapter
  #
  # @since 0.1.0
  class Cache
    class << self
      extend Forwardable

      delegate %w[current flush ready?] => :instance
    end

    include Singleton

    def initialize
      @mutex = Mutex.new
    end

    def ready?
      current.alive!
      true
    rescue Dalli::RingError
      false
    end

    def flush
      current.flush
    end

    def current
      return @current if @current

      @mutex.synchronize do
        @current ||= Dalli::Client.new(
          ENV.fetch('MEMCACHED_HOST', 'localhost:11211'),
          { timeout: 1, compress: true, namespace: 'unlight' }
        )
      end

      @current
    end
  end
end
