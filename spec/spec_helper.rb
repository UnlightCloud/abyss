# frozen_string_literal: true

require 'bundler/setup'
require 'super_diff/rspec'
require 'simplecov'
require 'simplecov-cobertura'
require 'faker'
require 'rack/test'

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

  if ENV.fetch('GITLAB_CI', false)
    formatter SimpleCov::Formatter::MultiFormatter.new([
                                                         SimpleCov::Formatter::SimpleFormatter,
                                                         SimpleCov::Formatter::CoberturaFormatter,
                                                         SimpleCov::Formatter::HTMLFormatter
                                                       ])
  end
end

ENV['DAWN_ENV'] = 'test'
ENV['ABYSS_ENV'] = 'test'

require 'abyss/prepare'
Abyss::Migrator.new(Abyss.app[:settings][:database_url]).migrate!

require_relative '../src/unlight'
require 'dry/system/stubs'

Unlight::Container.enable_stubs!
Abyss::Cache.flush # NOTE: Unlight cache breaks tests
Abyss.boot

Dir[Bundler.root.join('spec/support/**/*.rb')].each { |support| require support }

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
end
