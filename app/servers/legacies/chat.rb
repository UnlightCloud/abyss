# frozen_string_literal: true

module Unlight
  module Servers
    module Legacies
      # :nodoc:
      class Chat < Unlight::Servers::Legacy
        require 'protocol/chatserver'

        def server_class
          Unlight::Protocol::ChatServer
        end
      end
    end
  end
end
