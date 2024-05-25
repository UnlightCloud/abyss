# frozen_string_literal: true

module Unlight
  module API
    module Actions
      # :nodoc:
      class GetCharacterCards < Action
        def handle(_req, res)
          cards = Unlight::CharaCard.select(:id, :name)

          res.body = { data: cards }.to_json
        end
      end
    end
  end
end
