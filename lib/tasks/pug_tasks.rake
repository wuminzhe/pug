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
  raise "Network with chain_id #{chain_id} not found" if network_name.nil?
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

  puts "#{dir}/#{filename}"
end
