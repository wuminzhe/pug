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
      f.write JSON.pretty_generate(abi)
    end
  end

  puts filename
end

def select_abi
  dir = "#{Rails.root}/public/abis"
  filenames = Dir.foreach(dir).to_a.select { |filename| filename.end_with?('.json') }
  files = filenames.map do |filename|
    "#{dir}/#{filename}"
  end
  result = `echo "#{files.join("\n")}" | #{Rails.root}/bin/fzf --preview 'cat {}'`
  result.blank? ? nil : result.strip
end

# example:
# rails "app:add_contract[421_613,0x000000007e24da6666c773280804d8021e12e13f]"
desc 'Add a contract'
task :add_contract, %i[chain_id address] => :environment do |_t, args|
  abi_filename = select_abi
  if abi_filename.nil?
    puts 'No abi file selected'
    next
  end
  dir = "#{Rails.root}/public/abis"
  raise "File #{dir}/#{abi_filename} not found" unless File.exist?("#{dir}/#{abi_filename}")

  chain_id = args[:chain_id]
  address = args[:address]

  network = Pug::Network.find_by(chain_id: chain_id)
  raise "Network with chain_id #{chain_id} not found" if network.nil?

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

desc 'List abis files'
task :list_abis do
  dir = "#{Rails.root}/public/abis"
  Dir.foreach(dir) do |filename|
    puts "#{File.stat("#{dir}/#{filename}").ctime} - #{filename}" if filename.end_with?('.json')
  end
end
