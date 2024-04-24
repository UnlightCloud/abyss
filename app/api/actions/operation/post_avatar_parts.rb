# frozen_string_literal: true

module Unlight
  module API
    module Actions
      module Operation
        # :nodoc:
        class PostAvatarParts < Action
          params do
            required(:player_name).filled(:str?)
            required(:avatar_part_id).filled(:int?)
          end

          def handle(req, res)
            player = Unlight::Player[name: req.params[:player_name]]
            halt(:not_found, { error: 'Player not found' }.to_json) unless player

            res.body = {}.to_json
          end
        end
      end
    end
  end
end
