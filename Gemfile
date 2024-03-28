# frozen_string_literal: true

source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

# Common
gem 'prime'

# Server
gem 'eventmachine'

# Database
gem 'mysql2', '~> 0.5.6'
gem 'sequel', '~> 5.0'

# Cache
gem 'dalli'

# API Server
gem 'oj'
gem 'puma', '>= 5.3.1'
gem 'rack'

# Monitor
gem 'sentry-ruby'

# Utils
gem 'activesupport'
gem 'config'
gem 'gmp'
gem 'rake'
gem 'RubyInline', '~> 3.14.0'
gem 'semantic_logger'

group :build do
  gem 'RocketAMF', '~> 0.2.1'
  gem 'sqlite3'
end

group :development, :test do
  gem 'rubocop', '~> 1.57.2', require: false
  gem 'rubocop-performance', '>= 1.11.5', require: false
  gem 'rubocop-rspec', '>= 2.4.0', require: false
  gem 'rubocop-sequel', '>= 0.3.1', require: false
  gem 'rubocop-thread_safety', '>= 0.4.2', require: false
end

group :development do
  gem 'dotenv'
  gem 'ruby-lsp', require: false

  gem 'overcommit', require: false

  gem 'pry'
end

group :test do
  gem 'rspec', require: false
  gem 'rspec_junit_formatter', require: false

  gem 'cucumber', require: false
  gem 'database_cleaner', require: false
  gem 'database_cleaner-sequel', require: false
  gem 'factory_bot', require: false
  gem 'faker', require: false
  gem 'simplecov', '~> 0.22.0', require: false
  gem 'simplecov-cobertura', require: false

  gem 'rack-test', require: false

  gem 'super_diff', require: false
end
