# frozen_string_literal: true

module Unlight
  module API
    module Actions
      module Operation
        # :nodoc:
        class PostAvatarParts < Action
          def handle(_req, res)
            res.body = {}.to_json
          end
        end
      end
    end
  end
end
