# frozen_string_literal: true

module Unlight
  module Servers
    module Legacies
      # Reusable code for all servers
      module Liveiness
        def check_connection
          server_class.check_connection
        rescue StandardError => e
          logger.fatal('Check connection failed', e)
        end

        def check_connection_seconds
          server_class.check_connection_sec
        rescue StandardError => e
          logger.fatal('Check connection failed', e)
        end
      end
    end
  end
end
