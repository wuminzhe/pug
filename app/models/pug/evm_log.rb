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
    include AbiCoderRb

    belongs_to :network
    belongs_to :evm_contract
    belongs_to :evm_transaction

    alias contract evm_contract
    alias_attribute :signature, :topic0

    scope :with_network, ->(network) { where(network:) }
    scope :with_event, ->(event_name) { where(event_name:) }

    # scopes for decoded field query
    # https://www.postgresql.org/docs/9.5/functions-json.html
    # https://www.reddit.com/r/rails/comments/10a1fww/jsonb_queries_cheatsheet/
    scope :field_eq, ->(field, value) { where('decoded->>? = ?', field, value) }
    scope :field_gt, ->(field, value) { where('decoded->>? > ?', field, value) }
    scope :field_gte, ->(field, value) { where('decoded->>? >= ?', field, value) }
    scope :field_lt, ->(field, value) { where('decoded->>? < ?', field, value) }
    scope :field_lte, ->(field, value) { where('decoded->>? <= ?', field, value) }

    def self.create_from(network, log)
      evm_contract = EvmContract.find_by(network:, address: log['address'])
      raise "No contract for #{log['address']}" if evm_contract.nil?

      # CREATE EvmTransaction of this log if not existed
      #########################################
      evm_transaction = EvmTransaction.find_by(network:, transaction_hash: log['transaction_hash'])
      unless evm_transaction
        tx = network.client.eth_get_transaction_by_hash(log['transaction_hash'])
        evm_transaction = EvmTransaction.create!(
          network:,
          evm_contract:,
          block_hash: tx['blockHash'],
          block_number: tx['blockNumber'],
          chain_id: tx['chainId'],
          from: tx['from'],
          to: tx['to'],
          value: tx['value'],
          gas: tx['gas'],
          gas_price: tx['gasPrice'],
          transaction_hash: tx['hash'],
          input: tx['input'],
          max_priority_fee_per_gas: tx['maxPriorityFeePerGas'],
          max_fee_per_gas: tx['maxFeePerGas'],
          nonce: tx['nonce'],
          r: tx['r'],
          s: tx['s'],
          v: tx['v'],
          transaction_index: tx['transactionIndex'],
          transaction_type: tx['type']
        )
      end

      # CREATE EvmLog
      #########################################
      not_existed = find_by(
        network:,
        block_number: log['block_number'],
        transaction_index: log['transaction_index'],
        log_index: log['log_index']
      ).blank?

      unless not_existed
        puts "existed #{network.name}-#{log['block_number']}-#{log['transaction_index']}-#{log['log_index']}"
        return
      end

      evm_log = new(
        network:,
        evm_contract:,
        evm_transaction:,
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

      # DECODE
      #########################################
      evm_log.decode!

      # SAVE TO DB
      evm_log.save!
    end

    def topics
      [topic0, topic1, topic2, topic3].compact
    end

    def decode!
      self.event_name = evm_contract.event_name(topic0)
      p event_name

      event_abi = evm_contract.raw_event_abi(topic0)
      event_decoder = EventDecoder.new(event_abi)

      decoded_topics = event_decoder.decode_topics(topics, with_names: true)
      decoded_data = event_decoder.decode_data(data, with_names: true, flatten: true)

      self.decoded = decoded_topics.merge(decoded_data)

      p decoded
      puts ''
    end
  end
end
