# frozen_string_literal: true

module Unlight
  module API
    module Actions
      # :nodoc:
      class GetAvatarItems < Action
        def handle(_req, res)
          items = Unlight::AvatarItem.select(:id, :name)

          res.body = { data: items }.to_json
        end
      end
    end
  end
end
