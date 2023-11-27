require 'pug/version'
require 'pug/engine'
require 'pug/utils'
require 'api/etherscan'
require 'api/subscan'
require 'api/rpc_client'
require 'eth'
include Eth
require 'pug/abicoder'

require 'json'
#################################
# Task helper methods
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

    def get_contract_abi_from_explorer(chain_id, address)
      network_name = Pug::Network.find_by(chain_id:).name
      raise "Network with chain_id #{chain_id} not found" if network_name&.nil?

      return unless Api::Etherscan.respond_to? network_name

      explorer = if ENV['ETHERSCAN_API_KEY']
                   Api::Etherscan.send(network_name, ENV['ETHERSCAN_API_KEY'])
                 else
                   Api::Etherscan.send(network_name)
                 end
      contract_abi = explorer.extract_contract_abi(address)
      name = contract_abi[:contract_name]
      abi = contract_abi[:abi]
      [name, abi]
    end

    # 先从数据库中找其他链上的同名合约，
    # 找不到再从etherscan中找
    # 如果etherscan中也没有，就让用户选择本地的abi文件
    def prepare_abi(chain_id, address)
      file = find_abi_from_db_with_same_address(address)
      if file
        name = File.basename(file, '.json').split('-')[0]
        return [name, file]
      end

      # fetch abi from etherscan first.
      name, abi = get_contract_abi_from_explorer(chain_id, address)
      if name && abi
        file = save(name, abi)
        return [name, file]
      end

      # select abi file if not found on etherscan
      puts 'Select abi file from local'
      file = select_abi
      name = File.basename(file, '.json').split('-')[0]
      [name, file]
    end

    def find_abi_from_db_with_same_address(address)
      EvmContract.find_by(address:)&.abi_file
    end

    def get_creation_info(network, address)
      if Api::Etherscan.respond_to? network.name
        data = Api::Etherscan.send(network.name).contract_getcontractcreation({ contractaddresses: address })
        raise "Contract with address #{address} not found on etherscan" if data.empty?

        # TODO: check the rpc is available
        client = Api::RpcClient.new(network.rpc)
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
        raise "Can not get creation info for there is no explorer api found for network #{network.name}"
      end
    end

    def scan_logs_of_network(network, &block)
      from_block = network.last_scanned_block + 1

      # contract_event_sigs = network.evm_contracts.map do |contract|
      #   contract.event_signatures
      # end.flatten.uniq
      contract_event_sigs = nil
      logs, last_scanned_block = network.client.get_logs(
        network.evm_contracts.pluck(:address),
        contract_event_sigs,
        from_block,
        network.scan_span
      )

      # process logs
      nil if last_scanned_block <= from_block

      block.call logs, last_scanned_block
      network.update(last_scanned_block:)
      puts "   Scanned `#{network.display_name}` in [#{from_block},#{last_scanned_block}]"
      puts "\n"
    end

    def scan_logs_of_contract(network, contract, &block)
      # get logs from blockchain node
      from_block = contract.last_scanned_block + 1

      logs, last_scanned_block = network.client.get_logs(
        [contract.address],
        # contract.event_signaturestract.event_signatures,
        nil,
        from_block,
        network.scan_span
      )

      # process logs
      return if last_scanned_block <= from_block

      puts "Scanned `#{network.display_name}/#{contract.address}` in [#{from_block},#{last_scanned_block}]"
      block.call logs, last_scanned_block
      contract.update(last_scanned_block:)
    end

    # get the networks from contracts
    def active_networks
      Pug::EvmContract.includes(:network).map(&:network).uniq
    end

    def filter_rpc_list(rpc_list)
      rpc_list&.select { |rpc| rpc.start_with?('http') && rpc !~ /\$\{(.+)\}/ }
    end

    def active_networks_fastest_rpc
      require 'open-uri'

      chains = JSON.parse(URI.open('https://chainid.network/chains_mini.json').read)
      rpc_list_by_chain = chains.map do |chain|
        [chain['chainId'], chain['rpc']]
      end.to_h

      active_networks.map do |network|
        rpc_list = rpc_list_by_chain[network.chain_id]
        return [network.chain_id, nil, nil] if rpc_list.nil?

        rpc_list = filter_rpc_list(rpc_list)
        fastest_rpc = Pug::Utils.fastest_rpc(rpc_list)
        [network.chain_id, fastest_rpc].flatten
      end
    end
  end
end
