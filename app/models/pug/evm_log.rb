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
    belongs_to :network
    belongs_to :evm_contract
    belongs_to :evm_transaction

    alias contract evm_contract
    alias_attribute :signature, :topic0

    scope :with_network, ->(network) { where(network:) }
    scope :with_event, ->(event_name) { where(event_name:) }
    scope :field_eq, lambda { |field, value|
                       where('decoded->>? = ?', field, value)
                     }
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

    # {
    #   "inputs"=>[
    #     {
    #       "components"=>[
    #         {"internalType"=>"address", "name"=>"channel", "type"=>"address"},
    #         {"internalType"=>"uint256", "name"=>"index", "type"=>"uint256"},
    #         {"internalType"=>"uint256", "name"=>"fromChainId", "type"=>"uint256"},
    #         {"internalType"=>"address", "name"=>"from", "type"=>"address"},
    #         {"internalType"=>"uint256", "name"=>"toChainId", "type"=>"uint256"},
    #         {"internalType"=>"address", "name"=>"to", "type"=>"address"},
    #         {"internalType"=>"bytes", "name"=>"encoded", "type"=>"bytes"}
    #       ],
    #       "internalType"=>"struct Message",
    #       "name"=>"message",
    #       "type"=>"tuple"
    #     }
    #   ],
    #   "name"=>"clearFailedMessage",
    #   "outputs"=>[],
    #   "stateMutability"=>"nonpayable",
    #   "type"=>"function"
    # }
    def decode!
      #########################################
      # 1 - columns names
      #########################################
      event_column_names = evm_contract.event_columns(topic0).map { |c| c[0] }

      #########################################
      # 2 - columns values
      #########################################
      raw_event_abi = evm_contract.raw_event_abi(topic0)

      topic_inputs, data_inputs = raw_event_abi['inputs'].partition { |i| i['indexed'] }

      # TOPICS(indexed)
      topic_types = topic_inputs.map { |i| i['type'] }

      # If event is anonymous, all topics are arguments. Otherwise, the first
      # topic will be the event signature.
      topics_without_signature = topics[1..] if raw_event_abi['anonymous'] == false
      decoded_topics = topics_without_signature.map.with_index do |topic, i|
        topic_type = topic_types[i]
        Abicoder.decode([topic_type], hex(topic))[0]
      end

      # DATA
      data_types = data_inputs.map { |i| type(i) }
      decoded_data = Abicoder.decode(data_types, hex(data))

      event_column_values = decoded_topics + decoded_data
      event_column_values = transform_values(event_column_values).flatten

      #########################################
      # 3 - save
      #########################################
      record = Hash[event_column_names.zip(event_column_values)]
      self.event_name = evm_contract.event_name(topic0)
      self.decoded = record

      puts "   #{event_name}"
      print '   '
      p record
      puts ''
    end

    def transform_values(v)
      if v.is_a?(String) && v.encoding == Encoding::ASCII_8BIT
        binary_to_hex(v)
      elsif v.is_a?(String) && Utils.hex?(v)
        return "0x#{v}" unless v.start_with?('0x')

        v
      elsif v.is_a?(Array)
        v.map { |sub_v| transform_values(sub_v) }
      elsif v.is_a?(Hash)
        v.transform_values { |sub_v| transform_values(sub_v) }
      else
        v
      end
    end

    # binary string example:
    #   "\xF6T\xC1~\xA8\x91\b\xD7\x18>\xAF1\xC7b\xFE\f\x12]Gj\xA8\x13\t8\xD8\xA1\x89S\a\xB7\xDBZ"
    def binary_to_hex(binary)
      "0x#{binary.unpack1('H*')}"
    end

    # ['bytes32', 'tuple']
    #  ->
    # ['bytes32', '(address,uint256,uint256,address,uint256,address,bytes)']
    def type(input)
      if input['type'] == 'tuple'
        "(#{input['components'].map { |c| type(c) }.join(',')})"
      elsif input['type'] == 'enum'
        'uint8'
      else
        input['type']
      end
    end
  end
end
