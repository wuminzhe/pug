#################################
# Helper methods
#################################
module Pug
  class << self
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
      # TODO: check fzf installed
      # `fzf --version`
      result = `echo "#{files.join("\n")}" | fzf --preview 'cat {}'`
      result.blank? ? nil : result.strip
    end

    def get_contract_abi(chain_id, address)
      network_name = Pug::Network.find_by(chain_id:).name
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

      file = find_abi_from_db_with_same_address(address)
      return file unless file.nil?

      puts e.message
      puts 'Select abi file from local'

      # select abi file if not found on etherscan
      select_abi
    end

    def find_abi_from_db_with_same_address(address)
      EvmContract.find_by(address:)&.abi_file
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
        data = Api::Subscan.send(network.name).evm_contract({ address: })
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
      evm_contract.event_signatures.each do |event_signature|
        generate_model(evm_contract, event_signature)
      end
    end

    def generate_model(contract, event_signature)
      # model name
      model_name = contract.event_model_name(event_signature)

      # columns
      columns = contract.event_columns(event_signature)
      columns_str = columns.map { |c| "#{c[0]}:#{c[1]}:index" }.join(' ')

      if Pug.const_defined?(model_name)
        puts "    model already exists: Pug::#{model_name}"
      else
        system("./bin/rails g evm_event_model Pug::#{model_name} pug_evm_log:belongs_to #{columns_str} --no-test-framework")
      end
    end

    def scan_logs_of_network(network, &block)
      from_block = network.last_scanned_block + 1

      contract_event_sigs = network.evm_contracts.map do |contract|
        contract.event_signatures
      end.flatten.uniq
      logs, last_scanned_block = network.client.get_logs(
        network.evm_contracts.pluck(:address),
        contract_event_sigs,
        from_block,
        network.scan_span
      )

      # process logs
      nil if last_scanned_block <= from_block

      puts "scanned `#{network.name}` in [#{from_block},#{last_scanned_block}]"
      block.call logs, last_scanned_block
      network.update(last_scanned_block:)
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
      contract.update(last_scanned_block:)
    end
  end
end

#################################
# Tasks
#################################
task default: :pug

desc 'Explaining what the task does'
task :pug do
  puts "I'm a dog!"
end

namespace :pug do
  # example:
  # rails "app:add_contract_abi_from_file[Relayer, /workspaces/pug/test/dummy/public/abis/Relayer-b47bf80ce9.json]"
  desc 'Add contract abi from file'
  task :add_contract_abi_from_file, %i[name abi_file] => :environment do |_t, args|
    name = args[:name]
    abi = JSON.parse File.open(args[:abi_file]).read

    file = Pug.save(name, abi)
    puts "Abi file: #{file}"
  end

  # example:
  # rails "app:add_contract_abi[421_613,0x000000007e24da6666c773280804d8021e12e13f]"
  desc 'Add contract abi from a verified contract on etherscan'
  task :add_contract_abi, %i[chain_id address] => :environment do |_t, args|
    chain_id = args[:chain_id]
    address = args[:address]

    name, abi = Pug.get_contract_abi(chain_id, address)
    file = Pug.save(name, abi)
    puts "Abi file: #{file}"
  end

  # example:
  # rails "app:add_contract[421_613,0x000000007e24da6666c773280804d8021e12e13f]"
  desc 'Add a contract'
  task :add_contract, %i[chain_id address] => :environment do |_t, args|
    chain_id = args[:chain_id]
    address = args[:address].downcase

    abi_file = Pug.prepare_abi(chain_id, address)
    if abi_file.nil?
      puts 'No abi file found or selected.'
      next
    end

    network = Pug::Network.find_by(chain_id:)
    raise "Network with chain_id #{chain_id} not found" if network.nil?

    creation_info = Pug.get_creation_info(network, address)

    Pug::EvmContract.create!(
      network_id: network.id,
      address:,
      abi_file:,
      creator: creation_info[:creator],
      creation_tx_hash: creation_info[:tx_hash],
      creation_block: creation_info[:block],
      creation_timestamp: creation_info[:timestamp],
      last_scanned_block: creation_info[:block]
    )

    network.update!(last_scanned_block: creation_info[:block]) if network.last_scanned_block < creation_info[:block]

    puts "Contract #{address} on '#{network.display_name}' added"
  end

  desc 'Generate models for contracts'
  task generate_models: :environment do
    Pug::EvmContract.all.each do |contract|
      Pug.generate_models(contract)
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
    network = Pug::Network.find_by(chain_id:)

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
  task generate_procfile: :environment do
    File.open('Procfile.pug', 'w') do |f|
      Pug::EvmContract.all.each do |contract|
        f.puts "#{contract.network.name}_#{contract.name}: bin/rails \"pug:fetch_logs[#{contract.network.chain_id},#{contract.address}]\""
      end
    end

    # copy ./bin/pug to host app if not exists.
    pug_cli = File.expand_path('../../bin/pug', __dir__)
    dest = Rails.root.join('bin', 'pug')
    if File.exist?(dest)
      puts "#{dest} exists"
    else
      FileUtils.cp(pug_cli, dest)
      FileUtils.chmod('+x', dest)
      puts "create #{dest}"
    end
  end

  desc 'Reset contracts to creation block'
  task reset_contracts: :environment do
    Pug::EvmContract.all.each do |contract|
      contract.update(last_scanned_block: contract.creation_block)
      puts "== chain_id: #{contract.network.chain_id}, address: #{contract.address}, reset from #{contract.last_scanned_block} to #{contract.creation_block}"
      count = Pug::EvmLog.where(evm_contract_id: contract.id).delete_all
      puts "   deleted #{count} logs"
    end
  end

  desc 'Fetch logs of all contracts(serial processing)'
  task fetch_logs_all: :environment do
    $stdout.sync = true

    loop do
      Pug::EvmContract.all.each do |contract|
        network = contract.network

        begin
          ActiveRecord::Base.transaction do
            Pug.scan_logs_of_network(network) do |logs|
              logs.each do |log|
                Pug::EvmLog.create_from(network, log)
              end
            end
          end
        rescue StandardError => e
          puts e.message
          puts e.backtrace.join("\n") unless e.message.include? 'timeout'
          sleep 2
        end
      end

      sleep 2
    end
  end

  desc 'Fetch logs of a contract'
  task :fetch_logs, %i[chain_id address] => :environment do |_t, args|
    $stdout.sync = true

    network = Pug::Network.find_by(chain_id: args[:chain_id])
    raise "Network with chain_id #{args[:chain_id]} not found" if network.nil?

    contract = Pug::EvmContract.find_by(network:, address: args[:address])
    raise "Contract with address #{args[:address]} not found" if contract.nil?

    loop do
      ActiveRecord::Base.transaction do
        Pug.scan_logs_of_contract(network, contract) do |logs|
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
end
