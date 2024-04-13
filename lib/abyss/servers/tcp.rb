# frozen_string_literal: true

module Abyss
  module Servers
    # EventMachine based TCP server for legacy Unlight game server
    #
    # @since 0.1.0
    class Tcp
      require 'eventmachine'

      # @since 0.1.0
      ADDRESS = '0.0.0.0'

      # @since 0.1.0
      attr_reader :server_class, :id, :port, :hostname, :options

      # @param class_name [String] the server class name
      # @param id [String] the server IP address
      # @param port [Integer] the server port
      # @param hostname [String] the server hostname
      def initialize(server_class, **options)
        @server_class = server_class
        @id = options[:id]
        @port = options[:port]
        @hostname = options[:hostname]
        @options = options
      end

      # Start the server
      #
      # @since 0.1.0
      def start(&)
        EventMachine.set_descriptor_table_size(10_000)
        EventMachine.epoll

        Abyss.logger.name = server_class

        EventMachine.run do
          server_class.setup(id, hostname, port)
          EventMachine.start_server ADDRESS, port, server_class
          EventMachine.set_quantum(10)

          Abyss.logger.info("Listening #{server_class}... :#{port} as #{hostname}")
          ensure_database_connection(enabled: options[:check_database])

          yield if defined?(yield)
        end
      end

      # Stop the server
      #
      # @since 0.1.0
      def stop
        EventMachine.stop_event_loop
      end

      def ensure_database_connection(enabled: false)
        return unless enabled

        EventMachine::PeriodicTimer.new(60 * 60) do
          Abyss.logger.info('Checking database connection...')
          server_class.check_db_connection
        rescue StandardError => e
          Abyss.logger.fatal('Check database connection failed', e)
        end
      end
    end
  end
end
