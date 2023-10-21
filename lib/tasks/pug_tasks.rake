#################################
# Helper methods
#################################
def save(name, abi)
  # generate filename
  contract_abi_hash = Digest::SHA256.hexdigest(abi.to_json)
  filename = "#{name}-#{contract_abi_hash[-10..]}.json"

  # save to file
  dir = "#{Rails.root}/public/abis"
  FileUtils.mkdir_p(dir) unless Dir.exist?(dir)
  unless File.exist?("#{dir}/#{filename}")
    File.open("#{dir}/#{filename}", 'w') do |f|
      f.write JSON.pretty_generate(abi)
    end
  end

  "#{dir}/#{filename}"
end

def select_abi
  dir = "#{Rails.root}/public/abis"
  filenames = Dir.foreach(dir).to_a.select { |filename| filename.end_with?('.json') }
  files = filenames.map do |filename|
    "#{dir}/#{filename}"
  end
  result = `echo "#{files.join("\n")}" | fzf --preview 'cat {}'`
  result.blank? ? nil : result.strip
end

def get_contract_abi(chain_id, address)
  network_name = Pug::Network.find_by(chain_id: chain_id).name
  raise "Network with chain_id #{chain_id} not found" if network_name&.nil?

  raise 'No explorer api found for this network' unless Api::Etherscan.respond_to? network_name

  contract_abi = Api::Etherscan.send(network_name).extract_contract_abi(address)
  name = contract_abi[:contract_name]
  abi = contract_abi[:abi]
  [name, abi]
end

def prepare_abi(chain_id, address)
  # fetch abi from etherscan first.
  name, abi = get_contract_abi(chain_id, address)
  file = save(name, abi)
  puts "Abi file: #{file}"
  file
rescue StandardError => e
  raise e unless e.message.include? 'No explorer api found for this network'

  puts e.message
  puts 'Select abi file from local'

  # select abi file if not found on etherscan
  select_abi
end

def get_creation_info(network, address)
  if Api::Etherscan.respond_to? network.name
    data = Api::Etherscan.send(network.name).contract_getcontractcreation({ contractaddresses: address })
    raise "Contract with address #{address} not found on etherscan" if data.empty?

    # TODO: check the rpc is available
    client = Api::RpcClient.new(network.rpc_list.first)
    creation_block = client.eth_get_transaction_by_hash(data[0]['txHash'])['blockNumber'].to_i(16)
    creation_timestamp = client.get_block_by_number(creation_block)['timestamp'].to_i(16)

    {
      creator: data[0]['contractCreator'],
      tx_hash: data[0]['txHash'],
      block: creation_block,
      timestamp: Time.at(creation_timestamp)
    }
  elsif Api::Subscan.respond_to? network.name
    data = Api::Subscan.send(network.name).evm_contract({ address: address })
    raise "Contract with address #{address} not found on subscan" if data.blank?

    {
      creator: data['deployer'],
      tx_hash: data['transaction_hash'],
      block: data['block_num'],
      timestamp: Time.at(data['deploy_at'])
    }
  else
    raise "No explorer api found for network #{network.name}"
  end
end

def generate_models(evm_contract)
  event_abis = evm_contract.abi.select do |item|
    item['type'] == 'event'
  end
  event_abis.each do |event_abi|
    generate_model(evm_contract.name, event_abi)
  end
end

def build_columns(params)
  params
    .reduce([]) { |acc, param| acc + flat('p', param) }
    .map { |param| [param[0], to_rails_type(param[1])] }
end

def to_rails_type(abi_type)
  if abi_type == 'address'
    'string'
  elsif abi_type == 'bool'
    'boolean'
  elsif abi_type =~ /uint\d+/
    'integer'
  elsif abi_type =~ /int\d+/
    'integer'
  elsif abi_type =~ /bytes\d*/
    'string'
  else
    abi_type
  end
end

def flat(prefix, param)
  param_name, param_content = param
  param_name = param_name.underscore

  if param_content.is_a?(String)
    return [[param_name, param_content]] if prefix.nil?

    [["#{prefix}_#{param_name}", param_content]]
  elsif param_content.is_a?(Array)
    result = []
    param_content.each do |inner_param|
      result += flat("#{prefix}_#{param_name}", inner_param)
    end
    result
  end
end

# returns:
# [
#   ["root", "bytes32"],
#   ["message", [["channel", "address"], ["index", "uint256"], ["fromChainId", "uint256"], ["from", "address"], ["toChainId", "uint256"], ["to", "address"], ["encoded", "bytes"]]]
# ]
def get_params(inputs)
  inputs.map do |input|
    type(input)
  end
end

# result examples:
# ["root", "bytes32"]
# ["message", [["channel", "address"], ["index", "uint256"], ["fromChainId", "uint256"], ["from", "address"], ["toChainId", "uint256"], ["to", "address"], ["encoded", "bytes"]]]
def type(input)
  if input['type'] == 'tuple'
    [input['name'], input['components'].map { |c| type(c) }]
  elsif input['type'] == 'enum'
    [input['name'], 'uint8']
  else
    [input['name'], input['type']]
  end
end

def shorten_string(string)
  words = string.split('_')
  words.map { |word| word[0] }.join('')
end

def generate_model(contract_name, event_abi)
  # model name
  name = "#{contract_name.underscore}_#{event_abi['name'].underscore}"
  name = "#{shorten_string(contract_name.underscore)}_#{event_abi['name'].underscore}" if name.pluralize.length > 63
  model_name = name.camelize
  p model_name

  # columns
  event_inputs = event_abi.fetch('inputs', [])
  params = get_params(event_inputs)
  columns = build_columns(params)
  columns_str = columns.map { |c| "#{c[0]}:#{c[1]}:index" }.join(' ')
  p columns_str

  if Pug.const_defined?(model_name)
    puts "    model already exists: #{model_name}"
  else
    system("./bin/rails g model Pug::#{model_name} evm_event_log:belongs_to #{columns_str} --no-test-framework")
  end
end

def scan_logs_of_contract(network, contract, &block)
  # get logs from blockchain node
  from_block = contract.last_scanned_block + 1

  logs, last_scanned_block = network.client.get_logs(
    [contract.address],
    contract.event_signatures,
    from_block,
    network.scan_span
  )

  # process logs
  return if last_scanned_block <= from_block

  puts "scanned `#{network.name}/#{contract.address}` in [#{from_block},#{last_scanned_block}]"
  block.call logs, last_scanned_block
  contract.update(last_scanned_block: last_scanned_block)
end

#################################
# Tasks
#################################
task default: :pug

desc 'Explaining what the task does'
task :pug do
  puts "I'm a dog!"
end

# example:
# rails "app:add_contract_abi_from_file[Relayer, /workspaces/pug/test/dummy/public/abis/Relayer-b47bf80ce9.json]"
desc 'Add contract abi from file'
task :add_contract_abi_from_file, %i[name abi_file] => :environment do |_t, args|
  name = args[:name]
  abi = JSON.parse File.open(args[:abi_file]).read

  file = save(name, abi)
  puts "Abi file: #{file}"
end

# example:
# rails "app:add_contract_abi[421_613,0x000000007e24da6666c773280804d8021e12e13f]"
desc 'Add contract abi from a verified contract on etherscan'
task :add_contract_abi, %i[chain_id address] => :environment do |_t, args|
  chain_id = args[:chain_id]
  address = args[:address]

  name, abi = get_contract_abi(chain_id, address)
  file = save(name, abi)
  puts "Abi file: #{file}"
end

# example:
# rails "app:add_contract[421_613,0x000000007e24da6666c773280804d8021e12e13f]"
desc 'Add a contract'
task :add_contract, %i[chain_id address] => :environment do |_t, args|
  chain_id = args[:chain_id]
  address = args[:address]

  abi_file = prepare_abi(chain_id, address)
  if abi_file.nil?
    puts 'No abi file found or selected.'
    next
  end

  network = Pug::Network.find_by(chain_id: chain_id)
  raise "Network with chain_id #{chain_id} not found" if network.nil?

  creation_info = get_creation_info(network, address)

  Pug::EvmContract.create!(
    network_id: network.id,
    address: address.downcase,
    abi_file: abi_file,
    creator: creation_info[:creator],
    creation_tx_hash: creation_info[:tx_hash],
    creation_block: creation_info[:block],
    creation_timestamp: creation_info[:timestamp],
    last_scanned_block: creation_info[:block]
  )
end

desc 'Generate models for contracts'
task generate_models: :environment do
  Pug::EvmContract.all.each do |contract|
    generate_models(contract)
  end
end

desc 'List networks'
task list_networks: :environment do
  list = Pug::Network.all.map do |network|
    "#{network.chain_id}, #{network.name}, #{network.display_name}"
  end.join("\n")
  result = `echo "#{list}" | fzf`
  next if result.blank?

  chain_id = result.split(',')[0].strip
  network = Pug::Network.find_by(chain_id: chain_id)

  network.attributes.except('id').each do |k, v|
    print "#{k}: "
    if v.is_a? Time
      puts v
    else
      p v
    end
  end
end

desc 'List abis files'
task list_abis: :environment do
  dir = "#{Rails.root}/public/abis"
  Dir.foreach(dir) do |filename|
    puts "#{File.stat("#{dir}/#{filename}").ctime} - #{dir}/#{filename}" if filename.end_with?('.json')
  end
end

desc 'List contracts'
task list_contracts: :environment do
  Pug::EvmContract.all.each do |contract|
    puts "== chain_id: #{contract.network.chain_id}"
    contract.attributes.except('id', 'network_id').each do |k, v|
      print "   #{k}: "
      if v.is_a? Time
        puts v
      else
        p v
      end
    end
    puts "   cmd: rails \"fetch_logs[#{contract.network.chain_id},#{contract.address}]\""
  end
end

desc 'Print procfile items for contracts'
task print_procfile: :environment do
  Pug::EvmContract.all.each do |contract|
    puts "#{contract.name}: bin/rails \"fetch_logs[#{contract.network.chain_id},#{contract.address}]\""
  end
end

desc 'Fetch logs of a contract'
task :fetch_logs, %i[chain_id address] => :environment do |_t, args|
  $stdout.sync = true

  network = Pug::Network.find_by(chain_id: args[:chain_id])
  raise "Network with chain_id #{args[:chain_id]} not found" if network.nil?

  contract = Pug::EvmContract.find_by(network: network, address: args[:address])
  raise "Contract with address #{args[:address]} not found" if contract.nil?

  loop do
    ActiveRecord::Base.transaction do
      scan_logs_of_contract(network, contract) do |logs|
        logs.each do |log|
          Pug::EvmLog.create_from(network, log)
        end
      end
    end

    sleep 2
  rescue StandardError => e
    puts e.message
    puts e.backtrace.join("\n") unless e.message.include? 'timeout'
    sleep 10
  end
end
