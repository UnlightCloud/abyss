Dawn Server
===

[![Test](https://github.com/UnlightCloud/abyss/actions/workflows/main.yml/badge.svg)](https://github.com/UnlightCloud/abyss/actions/workflows/main.yml)
[![Containerize](https://github.com/UnlightCloud/abyss/actions/workflows/containerize.yml/badge.svg)](https://github.com/UnlightCloud/abyss/actions/workflows/containerize.yml)
[![Maintainability](https://api.codeclimate.com/v1/badges/0b9b05fdca13833dcfcb/maintainability)](https://codeclimate.com/github/UnlightCloud/abyss/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/0b9b05fdca13833dcfcb/test_coverage)](https://codeclimate.com/github/UnlightCloud/abyss/test_coverage)
[![CucumberReports: UnlightCloud/Abyss](https://messages.cucumber.io/api/report-collections/78b91caa-5111-4e8b-beca-3df0601f4f86/badge)](https://reports.cucumber.io/report-collections/78b91caa-5111-4e8b-beca-3df0601f4f86)

This is the Unlight server maintenance by [Open Unlight](https://unlight.app) and based the CPA's [Unlight](https://github.com/unlightcpa/Unlight/) server.

More information please reference ours [developer document](https://docs.unlight.dev/).

## Requirement

* Ruby 3.2.2
* MySQL 8.0
* Memcached
* SQLite (for development)

## Roadmap

* [ ] Refactor
  * [ ] Unit Test (In progress)
  * [ ] Feature Test
* [ ] Convert to Framework
  * [ ] Dawn Core
  * [ ] Dawn CLI
  * [ ] ...

## Setup

This project is under a Unix-like environment and suggests using macOS as the development environment and Linux as the production environment.

Below is for macOS to set up the development environment.

### Hombrew

```bash
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
```

After the script is executed, you can use `brew doctor` to ensure the configuration is correct.

### Ruby

There are two options for the virtual environment, you can choose `rbenv` or `rvm` to manage it.

```bash
# Use rbenv
brew install rbenv
brew install ruby-build

# Use rvm
brew install rvm
```

Please follow the terminal message to update `.bashrc` or your shell configuration.

```bash
# Use rbenv
rbenv install 2.6.7

# Use rvm
rvm install 2.6.7
```

You may need to install the bundler for the newly installed Ruby.


```bash
gem install bundler -v 2.1.4
```

### MySQL

The MySQL isn't the latest version, please notice don't use `mysql` instead of `mysql` for install.

```bash
# Install
brew install mysql

# Start Server
brew services start mysql
```

### Memcached

```bash
# Install
brew install memcached

# Start Server
brew services start memcached
```

### SQLite

```bash
brew install sqlite3
```

### Dawn Server

You can use the `bundler` to install the necessary RubyGems.

```bash
bundler install
```

If you got the error message for `mysql2` gem, you need extra configure it to install it.

```bash
export LIBRARY_PATH=$(brew --prefix openssl@1.1)/lib:$LIBRARY_PATH
gem install mysql2 -v 0.5.3 -- --with-mysql-config=/usr/local/opt/mysql/bin/mysql_config
```

## Development

We attach importance to the code quality, all codes should pass our static analysis and tests eg. Rubocop, RSpec, etc.

### RSpec

According to our coding guideline, each function should be tested with RSpec to ensure each unit are stable and safe to be changed.

Please run the RSpec test to ensure your change isn't break anythings.

```bash
bundle exec rspec
```

To keep we have a stable codebase, the coverage should be above 80%. Please add tests if you add something new.

### Cucumber

Currently, we are focus on the unit-test we will start working on the feature test after our refactor.

## Contributing

If you are interested to contribute to this project, we are welcome to see you [pull request](https://github.com/open-unlight/dawn/pulls) and discuss with you about improving it.

## License

This server is available as open source under the terms of the [Apache 2.0 License](https://opensource.org/licenses/Apache2.0).
