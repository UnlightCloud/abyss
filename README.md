Abyss
===

[![Test](https://github.com/UnlightCloud/abyss/actions/workflows/main.yml/badge.svg)](https://github.com/UnlightCloud/abyss/actions/workflows/main.yml)
[![Containerize](https://github.com/UnlightCloud/abyss/actions/workflows/containerize.yml/badge.svg)](https://github.com/UnlightCloud/abyss/actions/workflows/containerize.yml)
[![Maintainability](https://api.codeclimate.com/v1/badges/0b9b05fdca13833dcfcb/maintainability)](https://codeclimate.com/github/UnlightCloud/abyss/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/0b9b05fdca13833dcfcb/test_coverage)](https://codeclimate.com/github/UnlightCloud/abyss/test_coverage)
[![CucumberReports: UnlightCloud/Abyss](https://messages.cucumber.io/api/report-collections/78b91caa-5111-4e8b-beca-3df0601f4f86/badge)](https://reports.cucumber.io/report-collections/78b91caa-5111-4e8b-beca-3df0601f4f86)

Abssy is a community-driven project to make the Unlight server updated to date and maintainable.

## Usage

> Work in progress

## Development

The development environment is built on top of Docker and Docker Compose with dip gem to manage the development environment.

### Requirement

* Ruby 3.2+
* MySQL 8.0+
* Memcached

### Provision

```bash
dip provision
```

> If `data/` contains the game data it will be loaded into the database.

### Start Server

```bash
dip up
```

### Stop Server

```bash
dip stop
```

### Console

```bash
dip abyss console
```

### Cucumber

We are focused on E2E testing to ensure each behavior can be reproduced that didn't break anything when we working on refactoring and improvement.

```bash
dip cucumber
```

### RSpec

For each component and module, we will use RSpec to ensure the logic behind it is working as expected.

```bash
dip rspec
```

## License

This server is available as open source under the terms of the [Apache 2.0 License](https://opensource.org/licenses/Apache2.0).
