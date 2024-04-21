# frozen_string_literal: true

require 'bundler/setup'
require 'simplecov'
require 'faker'

require 'rspec'
require 'super_diff/rspec'

SimpleCov.start do
  load_profile 'test_frameworks'

  add_filter %r{^/vendor/}
  add_filter %r{^/config/}
  add_filter %r{^/db/}

  add_group 'Controllers', 'src/controller'
  add_group 'Models', 'src/model'
  add_group 'Protocols' do |src|
    src.filename.include?('src/protocol/') &&
      !src.filename.include?('command')
  end
  add_group 'Commands', 'src/protocol/command'
  add_group 'Rules', 'src/rule'
  add_group 'Libraries', 'lib/'
end

ENV['DAWN_ENV'] = 'test'
ENV['ABYSS_ENV'] = 'test'

require_relative '../../src/unlight'
require 'dry/system/stubs'

Abyss::Cache.flush # NOTE: Unlight cache breaks tests
Unlight::Container.enable_stubs!

Abyss.boot
