# frozen_string_literal: true

require 'database_cleaner'
require 'database_cleaner-sequel'

RSpec.configure do |config|
  DatabaseCleaner[:sequel].db = Unlight::Container[:database]
  DatabaseCleaner[:sequel].strategy = :transaction
  DatabaseCleaner[:sequel].clean_with(:truncation)

  config.around do |example|
    DatabaseCleaner[:sequel].cleaning do
      example.run
    end
  end
end
