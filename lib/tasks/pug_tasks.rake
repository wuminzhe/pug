#################################
# Tasks
#################################
task default: :pug

desc 'Explaining what the task does'
task :pug do
  puts "I'm a dog!"
end

namespace :pug do
  desc 'Fill networks'
  task fill_networks: :environment do
    require 'open-uri'
    networks = JSON.parse(URI.open('https://chainid.network/chains.json').read)
    ActiveRecord::Base.transaction do
      networks.each do |network|
        rpc = network['rpc']&.select { |url| url.start_with?('http') && url !~ /\$\{(.+)\}/ }&.first
        explorer = network['explorers']&.first&.[]('url')
        Pug::Network.create(
          chain_id: network['chainId'],
          name: network['shortName'].underscore,
          display_name: network['name'],
          rpc:,
          explorer:,
          scan_span: 2000
        )
      end
    end
  end

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

    network = Pug::Network.find_by(chain_id:)
    raise "Network with chain_id #{chain_id} not found" if network.nil?

    # check if contract exists
    contract = Pug::EvmContract.find_by(network:, address:)
    raise "Contract with address #{address} on #{chain_id} already exists" unless contract.nil?

    abi_file = Pug.prepare_abi(chain_id, address)
    if abi_file.nil?
      puts 'No abi file found or selected.'
      next
    end

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

    if network.last_scanned_block.zero? || creation_info[:block] < network.last_scanned_block
      network.update!(last_scanned_block: creation_info[:block])
    end

    puts "Contract #{address} on '#{network.display_name}' added"
  end

  desc 'Generate event models'
  task generate_event_models: :environment do
    Pug::EvmContract.all.each do |contract|
      Pug.generate_models(contract)
    end
  end

  desc 'Remove all generated event models with their migrations, and delete evm_contracts'
  task clear: :environment do
    Pug::EvmContract.all.each do |evm_contract|
      Pug.delete_models(evm_contract)
      evm_contract.destroy!
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
      puts "== ROUND: #{Time.now} ==============="
      Pug.active_networks.each do |network|
        puts "   - #{network.display_name}"
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

      sleep 2
    end
  end

  desc "Reset networks' last_scanned_block"
  task reset_scan_cursor: :environment do
    Pug::EvmContract.all.each do |contract|
      if contract.creation_block < contract.network.last_scanned_block
        contract.network.update!(last_scanned_block: contract.creation_block)
        puts "chain_id: #{contract.network.chain_id}, reset last_scanned_block to #{contract.creation_block}"
      end
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

  desc 'Update network rpc'
  task update_rpc: :environment do
    loop do
      fastest_rpcs = Pug.active_networks_fastest_rpc
      fastest_rpcs.each do |chain_id, rpc, _|
        next unless rpc.present?

        network = Pug::Network.find_by(chain_id:)
        if network.rpc != rpc
          network.update!(rpc:)
          puts "#{network.display_name}'s rpc updated to: `#{rpc}`"
        else
          puts "#{network.display_name}'s rpc is already the fastest: `#{rpc}`"
        end
      end

      sleep 60
    rescue StandardError => e
      puts e.message
      puts e.backtrace.join("\n") unless e.message.include? 'timeout'
      sleep 60
    end
  end
end
