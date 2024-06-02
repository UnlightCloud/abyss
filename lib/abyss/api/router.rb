# frozen_string_literal: true

require 'hanami/router'

module Abyss
  module Api
    # The API router
    #
    # @since 0.1.0
    class Router < Hanami::Router
      def initialize(routes:, **, &)
        instance_eval(&) if block_given?
        super(**, &routes)
      end
    end
  end
end
