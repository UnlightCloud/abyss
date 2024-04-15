# frozen_string_literal: true

module Unlight
  module Servers
    module Legacies
      # :nodoc:
      class Matching < Unlight::Servers::Legacy
        require 'protocol/matchserver'

        def server_class
          Unlight::Protocol::MatchServer
        end

        def start(*)
          super(*) do
            ensure_connection_seconds
            check_boot
            pop_cpu
            update_match_radder
            update_cpu_match_radder
          end
        end

        private

        def ensure_connection_seconds
          EventMachine::PeriodicTimer.new(60 / Unlight::GAME_CHECK_CONNECT_INTERVAL) do
            server_class.check_connection_sec
          rescue StandardError => e
            logger.fatal('Check connection failed', e)
          end
        end

        def check_boot
          EventMachine::PeriodicTimer.new(60) do
            server_class.check_boot
            server_class.update_login_count
          rescue StandardError => e
            logger.fatal('Check boot failed', e)
          end
        end

        def pop_cpu
          current_time = 0

          EventMachine::PeriodicTimer.new(Unlight::CPU_POP_TIME) do
            h = Time.now.utc.hour
            if current_time != h
              c = Unlight::CPU_SPAWN_NUM[h]
              c.times { Unlight::MatchController.cpu_room_update }
              current_time = h
            end
          rescue StandardError => e
            logger.fatal('Pop CPU failed', e)
          end
        end

        def update_match_radder
          EventMachine::PeriodicTimer.new(5) do
            server_class.radder_match_update
          rescue StandardError => e
            logger.fatal('Radder match update failed', e)
          end
        end

        def update_cpu_match_radder
          EventMachine::PeriodicTimer.new(Unlight::RADDER_CPU_POP_TIME) do
            Unlight::MatchController.cpu_radder_match_update if Unlight::RADDER_CPU_POP_ENABLE && rand(Unlight::RADDER_CPU_POP_RAND).zero?
          rescue StandardError => e
            logger.fatal('Radder CPU POP failed', e)
          end
        end
      end
    end
  end
end
