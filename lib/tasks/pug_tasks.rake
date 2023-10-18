desc 'Explaining what the task does'
task :pug do
  puts "I'm a dog!"
end

task default: :pug

# example:
# rails "app:add_contract_abi_from_file[Relayer, /workspaces/pug/test/dummy/public/abis/Relayer-b47bf80ce9.json]"
desc 'Add contract abi from file'
task :add_contract_abi_from_file, %i[name abi_file] => :environment do |_t, args|
  name = args[:name]
  abi = JSON.parse File.open(args[:abi_file]).read

  save(name, abi)
end

# example:
# rails "app:add_contract_abi[421_613,0x000000007e24da6666c773280804d8021e12e13f]"
desc 'Add contract abi from a verified contract on etherscan'
task :add_contract_abi, %i[chain_id address] => :environment do |_t, args|
  chain_id = args[:chain_id]
  address = args[:address]

  network_name = Pug::Network.find_by(chain_id: chain_id).name
  raise "Network with chain_id #{chain_id} not found" if network_name&.nil?

  raise "Api::Etherscan.#{network_name} not found" unless Api::Etherscan.respond_to? network_name

  contract_abi = Api::Etherscan.send(network_name).extract_contract_abi(address)
  name = contract_abi[:contract_name]
  abi = contract_abi[:abi]

  save(name, abi)
end

def save(name, abi)
  # generate filename
  contract_abi_hash = Digest::SHA256.hexdigest(abi.to_json)
  filename = "#{name}-#{contract_abi_hash[-10..]}.json"

  # save to file
  dir = "#{Rails.root}/public/abis"
  FileUtils.mkdir_p(dir) unless Dir.exist?(dir)
  unless File.exist?("#{dir}/#{filename}")
    File.open("#{dir}/#{filename}", 'w') do |f|
      f.write abi.to_json
    end
  end

  puts filename
end

desc 'Add a contract'
task :add_contract, %i[chain_id address abi_filename] => :environment do |_t, args|
  chain_id = args[:chain_id]
  address = args[:address]
  abi_filename = args[:abi_filename]

  network = Pug::Network.find_by(chain_id: chain_id)
  raise "Network with chain_id #{chain_id} not found" if network.nil?

  dir = "#{Rails.root}/public/abis"
  raise "File #{dir}/#{abi_filename} not found" unless File.exist?("#{dir}/#{abi_filename}")

  raise "Api::Etherscan.#{network_name} not found" unless Api::Etherscan.respond_to? network.name

  creation_info = Api::Etherscan.send(network.name).contract_getcontractcreation({ contractaddresses: address }).first

  # TODO: check the rpc is available
  client = Api::EvmClient.new(network.rpc_list.first)
  creation_block = client.eth_get_transaction_by_hash(creation_info['txHash'])['blockNumber'].to_i(16)

  Pug::EvmContract.create!(
    network_id: network.id,
    address: address,
    abi_file: abi_filename,
    creator: creation_info['contractCreator'],
    creation_tx_hash: creation_info['txHash'],
    creation_block: creation_block
  )
end
