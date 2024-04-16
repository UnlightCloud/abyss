# frozen_string_literal: true

module Unlight
  module Servers
    # :nodoc:
    class Legacy
      require 'eventmachine'

      include Deps[
        :logger,
        :settings,
      ]

      # @since 0.1.0
      ADDRESS = '0.0.0.0'

      def server_class
        raise NotImplementedError, 'The server_class must defined in the subclass'
      end

      # Start the server
      #
      # @since 0.1.0
      def start(id, hostname, port)
        EventMachine.set_descriptor_table_size(10_000)
        EventMachine.epoll

        logger.name = server_class

        EventMachine.run do
          server_class.setup(id, hostname, port)
          EventMachine.start_server ADDRESS, port, server_class
          EventMachine.set_quantum(10)

          logger.info("Listening #{server_class}... :#{port} as #{hostname}")
          every(1.hour) { ensure_database_connection } if settings.check_database

          yield if defined?(yield)
        end
      end

      # Stop the server
      #
      # @since 0.1.0
      def stop
        EventMachine.stop_event_loop
      end

      def every(interval, &)
        EventMachine::PeriodicTimer.new(interval) do
          yield if defined?(yield)
        end
      end

      def ensure_database_connection
        logger.info('Checking database connection...')
        server_class.check_db_connection
      rescue StandardError => e
        logger.fatal('Check database connection failed', e)
      end
    end
  end
end
