# frozen_string_literal: true

Abyss.app.register_provider :oj do
  prepare do
    require 'oj'
  end

  start do
    Oj.mimic_JSON
  end
end
