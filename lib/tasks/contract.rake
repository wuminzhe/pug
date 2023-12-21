namespace :pug do
  # example:
  # rails "app:add_contract[421_613,0x000000007e24da6666c773280804d8021e12e13f]"
  desc 'Add a contract'
  task :add_contract, %i[chain_id address] => :environment do |_t, args|
    chain_id = args[:chain_id].to_i

    tron = [2_494_104_990, 728_126_428].include?(chain_id)

    address, tron_address =
      if tron && Pug::TronAddress.tron_address?(args[:address])
        [
          "0x#{Pug::TronAddress.base58check_to_hex(args[:address])}",
          args[:address]
        ]
      else
        [
          args[:address].downcase,
          nil
        ]
      end

    network = Pug::Network.find_by(chain_id:)
    if network.nil?
      puts "Network with chain_id #{chain_id} not found"
      next
    end

    # check if contract exists
    contract = Pug::EvmContract.find_by(network:, address:)
    unless contract.nil?
      puts "Contract with address #{address} on #{chain_id} already exists"
      next
    end

    name, abi_file = Pug.prepare_abi(chain_id, tron_address || address)
    if abi_file.nil?
      puts 'No abi file found or selected.'
      next
    end

    creation_info = Pug::ContractInfo.creation_info(network, tron_address || address)

    Pug::EvmContract.create!(
      network_id: network.id,
      address:,
      name:,
      abi_file:,
      creator: creation_info[:creator],
      creation_tx_hash: creation_info[:tx_hash],
      creation_block: creation_info[:block],
      creation_timestamp: creation_info[:timestamp],
      last_scanned_block: creation_info[:block],
      tron_address:
    )

    if network.last_scanned_block.zero? || creation_info[:block] < network.last_scanned_block
      network.update!(last_scanned_block: creation_info[:block])
    end

    puts "Contract #{tron_address || address} on '#{network.display_name}' added"
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

  desc 'Reset contracts to creation block'
  task reset_contracts: :environment do
    Pug::EvmContract.all.each do |contract|
      contract.update(last_scanned_block: contract.creation_block)
      puts "== chain_id: #{contract.network.chain_id}, address: #{contract.address}, reset from #{contract.last_scanned_block} to #{contract.creation_block}"
      count = Pug::EvmLog.where(evm_contract_id: contract.id).delete_all
      puts "   deleted #{count} logs"
    end
  end
end
