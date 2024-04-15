# frozen_string_literal: true

module Unlight
  module Servers
    module Legacies
      # :nodoc:
      class Watch < Unlight::Servers::Legacy
        require 'protocol/watchserver'

        def server_class
          Unlight::Protocol::WatchServer
        end

        def start(*)
          super(*) do
            update_duels
            ensure_connection
          end
        end

        private

        def update_duels
          EventMachine::PeriodicTimer.new(1) do
            server_class.all_duel_update
          rescue StandardError => e
            logger.fatal('All duel update failed', e)
          end
        end

        def ensure_connection
          EventMachine::PeriodicTimer.new(60) do
            server_class.check_connection
          rescue StandardError => e
            logger.fatal('Check connection failed', e)
          end
        end
      end
    end
  end
end
