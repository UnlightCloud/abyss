# frozen_string_literal: true

module Unlight
  # :nodoc:
  class Routes < Abyss::Api::Routes
    get '/', to: 'root'

    scope 'v1' do
      get '/avatar_parts', to: 'get_avatar_parts'
      get '/avatar_items', to: 'get_avatar_items'

      scope 'operation' do
        post '/avatar_parts', to: 'operation.post_avatar_parts'
      end
    end
  end
end
