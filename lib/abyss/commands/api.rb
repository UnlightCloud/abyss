# frozen_string_literal: true

module Abyss
  # :nodoc:
  module Commands
    # Start the api server
    #
    # @since 0.1.0
    class Api < Dry::CLI::Command
      desc 'Start the API server'

      option :Port, type: :integer, default: 3000, desc: 'The port to bind to', aliases: ['-p']

      def call(**)
        require 'rack'
        require Abyss.root.join('src', 'unlight')
        Abyss.boot

        Rack::Handler.default.run(Abyss::Api, **)
      end
    end

    register 'api', Api
  end
end
