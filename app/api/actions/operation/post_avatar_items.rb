# frozen_string_literal: true

module Unlight
  module API
    module Actions
      module Operation
        # :nodoc:
        class PostAvatarItems < Action
          params do
            required(:player_name).filled(:str?)
            required(:avatar_item_id).filled(:int?)
          end

          def handle(req, res)
            player = Unlight::Player[name: req.params[:player_name]]
            halt(:not_found, { error: 'Player not found' }.to_json) unless player

            avatar = player.current_avatar
            halt(:not_found, { error: 'Avatar not found' }.to_json) if avatar.new?

            item = Unlight::AvatarItem[req.params[:avatar_item_id]]
            halt(:not_found, { error: 'Avatar Item not found' }.to_json) unless item

            ret = avatar.get_item(item.id)
            halt(:bad_request, { error: 'Unable to grant avatar item' }.to_json) unless ret

            res.body = {
              avatar_id: avatar.id,
              avatar_item_id: item.id
            }.to_json
          end
        end
      end
    end
  end
end
