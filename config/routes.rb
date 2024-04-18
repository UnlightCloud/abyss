# frozen_string_literal: true

module Unlight
  # :nodoc:
  class Routes < Abyss::Api::Routes
    get '/', to: 'root'
  end
end
