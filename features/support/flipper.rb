# frozen_string_literal: true

Flipper.configure do |config|
  config.adapter do
    Flipper::Adapters::Memory.new
  end
end
