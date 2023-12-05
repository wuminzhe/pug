require 'pug/version'

require 'abi_coder_rb'
require 'etherscan'
require 'eth'
include Eth
require 'json'

require 'pug/engine'
require 'pug/utils'
require 'pug/json_rpc_client'
require 'pug/contract_info'
require 'pug/tron_address'

#################################
# Task helper methods
#################################
module Pug
  class << self
    def save(name, abi)
      # for tron abi
      abi = abi.map do |item|
        item['type'] = item['type'].downcase
        item['anonymous'] = false if item['anonymous'].nil?
        item['inputs'] = [] if item['inputs'].nil?
        item
      end
      abi = abi.filter { |item| item['type'] == 'event' }

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
      name, abi = ContractInfo.contract_abi(chain_id, address)
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
      puts "== Scanned `#{network.display_name}` in [#{from_block},#{last_scanned_block}]"
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
