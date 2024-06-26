# frozen_string_literal: true

module Unlight
  # :nodoc:
  class Routes < Abyss::Api::Routes
    get '/', to: 'root'

    scope 'v1' do
      get '/avatar_parts', to: 'get_avatar_parts'
      get '/avatar_items', to: 'get_avatar_items'
      get '/character_cards', to: 'get_character_cards'
      get '/weapon_cards', to: 'get_weapon_cards'

      scope 'operation' do
        post '/avatar_parts', to: 'operation.post_avatar_parts'
        post '/avatar_items', to: 'operation.post_avatar_items'
      end
    end
  end
end
