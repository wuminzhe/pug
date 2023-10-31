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

    alias contract evm_contract
    alias_attribute :signature, :topic0

    def self.create_from(network, log)
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

      evm_contract = EvmContract.find_by(network:, address: log['address'])

      evm_log = new(
        network:,
        evm_contract:,
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

      evm_log.save!
      evm_log.decode
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
    def decode
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
      # 3 - find model for this event then save
      #########################################
      event_model_class = Pug.const_get(evm_contract.event_model_name(topic0))
      raise "No model for event #{topic0}" if event_model_class.nil?

      record = Hash[event_column_names.zip(event_column_values)]
      puts '=='
      p event_model_class.name
      p record
      puts ''
      record[:pug_evm_log] = self
      record[:pug_evm_contract] = evm_contract
      record[:pug_network] = network
      record[:block_number] = block_number
      record[:timestamp] = timestamp
      event_model_class.create!(record)
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
