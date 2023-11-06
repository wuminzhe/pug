# == Schema Information
#
# Table name: pug_evm_contracts
#
#  id                 :integer          not null, primary key
#  network_id         :integer
#  address            :string
#  name               :string
#  abi_file           :string
#  creator            :string
#  creation_block     :integer
#  creation_tx_hash   :string
#  creation_timestamp :datetime
#  last_scanned_block :integer
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
module Pug
  class EvmContract < ApplicationRecord
    belongs_to :network

    alias_attribute :contract_name, :name

    def raw_abi
      read_abi
    end
    alias abi raw_abi

    def raw_event_abi(name_or_signature)
      raw_abi.find do |item|
        item['type'] == 'event' && item['name'] == parsed_event_abi(name_or_signature).name
      end
    end

    def parsed_abi
      @parsed_abi ||= parse_abi
    end

    def parsed_events_abi
      parsed_abi.events
    end
    alias events parsed_events_abi

    def parsed_event_abi(name_or_signature)
      if hex? name_or_signature
        parsed_abi.events.find do |event|
          event.signature == remove_0x(name_or_signature)
        end
      else
        parsed_abi.events.find do |event|
          event.name == name_or_signature
        end
      end
    end

    def event_signatures
      parsed_abi.events.map(&:signature).map { |sig| "0x#{sig}" }
    end

    def event_columns(name_or_signature)
      event_inputs = raw_event_abi(name_or_signature).fetch('inputs', [])
      params = get_params(event_inputs)
      build_columns(params)
    end

    def event_model_name(name_or_signature)
      event_name = parsed_event_abi(name_or_signature).name
      model_name = "#{contract_name.underscore}_#{event_name.underscore}"
      if model_name.pluralize.length > 63
        model_name = "#{shorten_string(contract_name.underscore)}_#{event_name.underscore}"
      end
      model_name.singularize.camelize
    end

    private

    def shorten_string(string)
      words = string.split('_')
      words.map { |word| word[0] }.join('')
    end

    def hex?(str)
      str = remove_0x(str)

      str.chars.all? { |c| c =~ /[a-fA-F0-9]/ }
    end

    def remove_0x(str)
      str = str[2..] if str.start_with?('0x')
      str
    end

    def parse_abi
      filename = abi_file.split('/').last
      name = filename.split('-')[0]
      Eth::Contract.from_abi(abi: read_abi, address:, name:)
    end

    def read_abi
      JSON.parse(File.read(abi_file))
    end

    # TODO: prefix config
    def build_columns(params)
      params
        .reduce([]) { |acc, param| acc + Pug::Utils.flat(nil, param) }
        .map { |param| [param[0], to_rails_type(param[1])] }
    end

    def to_rails_type(abi_type)
      if abi_type == 'address'
        'string'
      elsif abi_type == 'bool'
        'boolean'
      elsif abi_type == 'uint256'
        'decimal{78,0}'
      elsif abi_type == 'uint128'
        'decimal{39,0}'
      elsif abi_type == 'uint64'
        'decimal{20,0}'
      elsif abi_type =~ /int\d+/
        'bigint'
      elsif abi_type =~ /bytes\d*/
        'string'
      else
        abi_type
      end
    end

    # returns:
    # [
    #   ["root", "bytes32"], <-------- name, type(content)
    #   ["message", [["channel", "address"], ["index", "uint256"], ["fromChainId", "uint256"], ["from", "address"], ["toChainId", "uint256"], ["to", "address"], ["encoded", "bytes"]]]
    # ]
    def get_params(inputs)
      inputs.map do |input|
        type(input)
      end
    end

    # result examples:
    # ["root", "bytes32"]
    # ["message", [["channel", "address"], ["index", "uint256"], ["fromChainId", "uint256"], ["from", "address"], ["toChainId", "uint256"], ["to", "address"], ["encoded", "bytes"]]]
    def type(input)
      if input['type'] == 'tuple'
        [input['name'], input['components'].map { |c| type(c) }]
      elsif input['type'] == 'enum'
        [input['name'], 'uint8']
      else
        [input['name'], input['type']]
      end
    end
  end
end
