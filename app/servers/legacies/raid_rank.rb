# frozen_string_literal: true

module Unlight
  module Servers
    module Legacies
      # :nodoc:
      class RaidRank < Unlight::Servers::Legacy
        require 'protocol/raidrankserver'

        def server_class
          Unlight::Protocol::RaidRankServer
        end
      end
    end
  end
end
