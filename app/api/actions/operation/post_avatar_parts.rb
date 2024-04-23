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

          def handle(_req, res)
            res.body = {}.to_json
          end
        end
      end
    end
  end
end
