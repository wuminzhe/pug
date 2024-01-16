require 'pug/version'

require 'abi_coder_rb'
require 'etherscan'
require 'eth'
include Eth
require 'json'

require 'pug/engine'
require 'pug/utils'
require 'pug/json_rpc_client'
require 'pug/tron_address'
require 'pug/model'
require 'pug/trongrid'

require 'generators/evm_event_model/evm_event_model_generator'

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
  end
end
