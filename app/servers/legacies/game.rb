# frozen_string_literal: true

module Unlight
  module Servers
    module Legacies
      # :nodoc:
      class Game < Unlight::Servers::Legacy
        require 'protocol/gameserver'

        def server_class
          Unlight::Protocol::GameServer
        end

        def start(*)
          super(*) do
            update_duel
            update_ai
            ensure_connection_seconds
          end
        end

        private

        def update_duel
          EventMachine::PeriodicTimer.new(0.3) do
            Unlight::MultiDuel.update
          rescue StandardError => e
            logger.fatal('MultiDuel update failed', e)
          end
        end

        def update_ai
          EventMachine::PeriodicTimer.new(1) do
            Unlight::AI.update
          rescue StandardError => e
            logger.fatal('AI update failed', e)
          end
        end

        def ensure_connection_seconds
          EventMachine::PeriodicTimer.new(60 / Unlight::GAME_CHECK_CONNECT_INTERVAL) do
            server_class.check_connection_sec
          rescue StandardError => e
            logger.fatal('Check connection failed', e)
          end
        end
      end
    end
  end
end
