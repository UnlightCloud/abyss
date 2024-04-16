# frozen_string_literal: true

module Unlight
  module Servers
    module Legacies
      # :nodoc:
      class Watch < Unlight::Servers::Legacy
        require 'protocol/watchserver'

        include Liveiness

        def server_class
          Unlight::Protocol::WatchServer
        end

        def start(*)
          super(*) do
            every(1.second) { update_duels }
            every(1.minute) { check_connection }
          end
        end

        private

        def update_duels
          server_class.all_duel_update
        rescue StandardError => e
          logger.fatal('All duel update failed', e)
        end
      end
    end
  end
end
