# frozen_string_literal: true

module Unlight
  module Servers
    module Legacies
      # :nodoc:
      class Game < Unlight::Servers::Legacy
        require 'protocol/gameserver'

        include Liveiness
        include GamePlay

        def server_class
          Unlight::Protocol::GameServer
        end

        def start(*)
          super do
            every(0.3.seconds) { update_duel }
            every(1.second) { update_ai }
            every(settings.game.check_connect_interval) { check_connection_seconds }
          end
        end
      end
    end
  end
end
