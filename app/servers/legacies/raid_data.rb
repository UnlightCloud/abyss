# frozen_string_literal: true

module Unlight
  module Servers
    module Legacies
      # :nodoc:
      class RaidData < Unlight::Servers::Legacy
        require 'protocol/raiddataserver'

        def server_class
          Unlight::Protocol::RaidDataServer
        end
      end
    end
  end
end
