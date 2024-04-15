# frozen_string_literal: true

module Unlight
  module Servers
    module Legacies
      # :nodoc:
      class Auth < Unlight::Servers::Legacy
        require 'protocol/authserver'

        def server_class
          Unlight::Protocol::AuthServer
        end
      end
    end
  end
end
