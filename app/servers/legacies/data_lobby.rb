# frozen_string_literal: true

module Unlight
  module Servers
    module Legacies
      # :nodoc:
      class DataLobby < Unlight::Servers::Legacy
        require 'protocol/dataserver'

        def server_class
          Unlight::Protocol::DataServer
        end
      end
    end
  end
end
