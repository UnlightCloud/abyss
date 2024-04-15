# frozen_string_literal: true

module Unlight
  module Servers
    module Legacies
      # :nodoc:
      class RaidChat < Unlight::Servers::Legacy
        require 'protocol/raidchatserver'

        def server_class
          Unlight::Protocol::RaidChatServer
        end
      end
    end
  end
end
