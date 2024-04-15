# frozen_string_literal: true

module Unlight
  # :nodoc:
  class Settings < Abyss::Settings
    setting :database_url

    # Server settings
    setting :check_database, default: false
  end
end
