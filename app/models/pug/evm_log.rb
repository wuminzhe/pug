# == Schema Information
#
# Table name: pug_evm_logs
#
#  id                :integer          not null, primary key
#  network_id        :integer
#  evm_contract_id   :integer
#  address           :string
#  data              :text
#  block_hash        :string
#  block_number      :integer
#  transaction_hash  :string
#  transaction_index :integer
#  log_index         :integer
#  timestamp         :datetime
#  topic0            :string
#  topic1            :string
#  topic2            :string
#  topic3            :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
module Pug
  class EvmLog < ApplicationRecord
    belongs_to :evm_contract
    belongs_to :network

    def self.create_from(network, log)
      not_existed = find_by(
        network: network,
        block_number: log['block_number'],
        transaction_index: log['transaction_index'],
        log_index: log['log_index']
      ).blank?

      unless not_existed
        puts "existed #{network.name}-#{log['block_number']}-#{log['transaction_index']}-#{log['log_index']}"
        return
      end

      evm_contract = EvmContract.find_by(network: network, address: log['address'])

      evm_log = new(
        network: network,
        evm_contract: evm_contract,
        address: log['address'],
        data: log['data'],
        block_number: log['block_number'],
        transaction_hash: log['transaction_hash'],
        transaction_index: log['transaction_index'],
        block_hash: log['block_hash'],
        log_index: log['log_index'],
        timestamp: Time.at(log['timestamp'])
      )
      log['topics'].each_with_index do |topic, index|
        evm_log.send("topic#{index}=", topic)
      end

      evm_log.save
    end
  end
end
