# Pug
Short description and motivation.

## Usage

```bash
# Setup:
rails db:create
rails pug:install:migrations
rails db:migrate

# Add contracts:
rails pug:add_contract[chain_id,address]
rails pug:add_contract[chain_id,address]
# ...
rails pug:generate_event_models
rails db:migrate

# sync data
rails pug:fetch_logs_all
# or
rails pug:generate_procfile
./bin/pug

```

## Installation
Add this line to your application's Gemfile:

```ruby
gem "pug"
```

And then execute:
```bash
$ bundle
```

Or install it yourself as:
```bash
$ gem install pug
```

## Contributing
Contribution directions go here.

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
