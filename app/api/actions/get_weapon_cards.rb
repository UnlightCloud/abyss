# frozen_string_literal: true

module Unlight
  module API
    module Actions
      # :nodoc:
      class GetWeaponCards < Action
        def handle(_req, res)
          cards = Unlight::WeaponCard.select(:id, :name)

          res.body = { data: cards }.to_json
        end
      end
    end
  end
end
