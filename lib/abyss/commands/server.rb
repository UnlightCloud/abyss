# frozen_string_literal: true

module Abyss
  # :nodoc:
  module Commands
    # Start the server
    #
    # @since 0.1.0
    class Server < Dry::CLI::Command
      TYPE_ALIASES = {
        'auth' => 'authentication'
      }.freeze

      desc 'Start the server'

      argument :type, required: true, desc: 'The server type'
      option :id, type: :integer, default: 0, desc: 'The server id', aliases: ['-i']
      option :port, type: :integer, default: 12_000, desc: 'The port to bind to', aliases: ['-p']
      option :hostname, type: :string, default: 'localhost', desc: 'The hostname to bind to', aliases: ['-h']

      def call(type:, **options)
        require 'eventmachine'
        require Abyss.root.join('src', 'unlight')
        Abyss.boot

        server = Abyss.app.resolve("servers.legacies.#{type}")
        Signal.trap(:INT) { server.stop }
        Signal.trap(:TERM) { server.stop }

        server.start(options[:id], options[:hostname], options[:port])
        Abyss.logger.info("Stopping #{type} server...")
        Abyss.shutdown
      rescue Dry::Core::Container::KeyError
        raise ArgumentError, "Unknown server type: #{type}"
      end
    end

    register 'server', Server, aliases: ['s']
  end
end
