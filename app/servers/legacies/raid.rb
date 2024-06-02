# frozen_string_literal: true

module Unlight
  module Servers
    module Legacies
      # :nodoc:
      class Raid < Unlight::Servers::Legacy
        require 'protocol/raid_server'

        include Liveiness
        include GamePlay

        def server_class
          Unlight::Protocol::RaidServer
        end

        def start(*)
          super do
            every(0.3.seconds) { update_duel }
            every(1.second) { update_ai }
            every(1.minute) { check_connection }
          end
        end
      end
    end
  end
end
