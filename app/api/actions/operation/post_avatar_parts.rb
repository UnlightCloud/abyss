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

            avatar = player.current_avatar
            halt(:not_found, { error: 'Avatar not found' }.to_json) if avatar.new?

            part = Unlight::AvatarPart[req.params[:avatar_part_id]]
            halt(:not_found, { error: 'Avatar Part not found' }.to_json) unless part

            ret = avatar.get_part(part.id, true)
            halt(:bad_request, { error: 'Avatar Part is duplicate' }.to_json) if ret == Unlight::ERROR_PARTS_DUPE

            res.body = {
              avatar_id: avatar.id,
              avatar_part_id: part.id
            }.to_json
          end
        end
      end
    end
  end
end
