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

## All rake tasks
```bash
# rails -T|grep pug                                            
bin/rails pug                                            # Explaining what the task does
bin/rails pug:add_contract[chain_id,address]             # Add a contract
bin/rails pug:add_contract_abi[chain_id,address]         # Add contract abi from a verified contract on etherscan
bin/rails pug:add_contract_abi_from_file[name,abi_file]  # Add contract abi from file
bin/rails pug:clear_event_models                         # Clear event models
bin/rails pug:fetch_logs[chain_id,address]               # Fetch logs of a contract
bin/rails pug:fetch_logs_all                             # Fetch logs of all contracts(serial processing)
bin/rails pug:generate_event_models                      # Generate event models
bin/rails pug:generate_procfile                          # Print procfile items for contracts
bin/rails pug:install:migrations                         # Copy migrations from pug to application
bin/rails pug:list_abis                                  # List abis files
bin/rails pug:list_contracts                             # List contracts
bin/rails pug:list_networks                              # List networks
bin/rails pug:reset_contracts                            # Reset contracts to creation block
bin/rails pug:show_events[chain_id,address]              # Show events of a contract
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
