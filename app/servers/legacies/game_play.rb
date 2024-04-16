# frozen_string_literal: true

module Unlight
  module Servers
    module Legacies
      # Shared game play module
      module GamePlay
        def update_duel
          Unlight::MultiDuel.update
        rescue StandardError => e
          logger.fatal('MultiDuel update failed', e)
        end

        def update_ai
          Unlight::AI.update
        rescue StandardError => e
          logger.fatal('AI update failed', e)
        end
      end
    end
  end
end
