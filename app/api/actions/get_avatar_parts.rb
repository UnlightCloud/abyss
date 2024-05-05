# frozen_string_literal: true

module Unlight
  module API
    module Actions
      # :nodoc:
      class GetAvatarParts < Action
        def handle(_req, res)
          parts = Unlight::AvatarPart.select(:id, :name)

          res.body = { data: parts }.to_json
        end
      end
    end
  end
end
