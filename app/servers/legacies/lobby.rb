# frozen_string_literal: true

module Unlight
  module Servers
    module Legacies
      # :nodoc:
      class Lobby < Unlight::Servers::Legacy
        require 'protocol/lobbyserver'

        def server_class
          Unlight::Protocol::LobbyServer
        end
      end
    end
  end
end
