# frozen_string_literal: true

module Abyss
  module Providers
    # Built-in inflector provider
    #
    # @since 0.1.0
    class Inflector < Dry::System::Provider::Source
      # @api private
      def start
        register :inflector, Abyss.app.inflector
      end
    end
  end
end
