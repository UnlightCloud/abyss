# frozen_string_literal: true

module Unlight
  module Servers
    module Legacies
      # :nodoc:
      class Matching < Unlight::Servers::Legacy
        require 'protocol/matchserver'

        include Liveiness

        def server_class
          Unlight::Protocol::MatchServer
        end

        def start(*)
          @current_time = 0

          super(*) do
            every(settings.game.check_connect_interval) { check_connection_seconds }
            every(1.minute) { check_boot }
            every(settings.cpu_pop_interval) { pop_cpu }
            every(5.seconds) { update_match_radder }
            every(settings.radder_cpu_pop_interval) { update_cpu_match_radder }
          end
        end

        private

        def check_boot
          server_class.check_boot
          server_class.update_login_count
        rescue StandardError => e
          logger.fatal('Check boot failed', e)
        end

        def pop_cpu
          h = Time.now.utc.hour
          if @current_time != h
            c = Unlight::CPU_SPAWN_NUM[h]
            c.times { Unlight::MatchController.cpu_room_update }
            @current_time = h
          end
        rescue StandardError => e
          logger.fatal('Pop CPU failed', e)
        end

        def update_match_radder
          server_class.radder_match_update
        rescue StandardError => e
          logger.fatal('Radder match update failed', e)
        end

        def update_cpu_match_radder
          return unless Unlight::RADDER_CPU_POP_ENABLE && rand(Unlight::RADDER_CPU_POP_RAND).zero?

          Unlight::MatchController.cpu_radder_match_update
        rescue StandardError => e
          logger.fatal('Radder CPU POP failed', e)
        end
      end
    end
  end
end
