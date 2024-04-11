# frozen_string_literal: true

module Abyss
  class Settings
    # The default store for settings
    #
    # @since 0.1.0
    class EnvStore
      NO_ARG = Object.new.freeze

      attr_reader :store

      # @api private
      def initialize(store: ENV)
        @store = store
      end

      def fetch(key, default = NO_ARG, &)
        name = key.to_s.upcase
        args = default.eql?(NO_ARG) ? [name] : [name, default]

        store.fetch(*args, &)
      end
    end
  end
end
