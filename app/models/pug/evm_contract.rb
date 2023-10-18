# == Schema Information
#
# Table name: pug_evm_contracts
#
#  id               :integer          not null, primary key
#  network_id       :integer          not null
#  address          :string
#  abi_file         :string
#  creator          :string
#  creation_block   :integer
#  creation_tx_hash :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
module Pug
  class EvmContract < ApplicationRecord
    belongs_to :network

    def parsed_abi
      @parsed_abi ||= parse_abi
    end

    def event_abi(name_or_signature)
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

    private

    def hex?(str)
      str = remove_0x(str)

      str.chars.all? { |c| c =~ /[a-fA-F0-9]/ }
    end

    def remove_0x(str)
      str = str[2..] if str.start_with?('0x')
      str
    end

    def parse_abi
      abi = JSON.parse(File.read("#{Rails.root}/public/abis/#{abi_file}"))
      name = abi_file.split('-')[0]
      Eth::Contract.from_abi(abi: abi, address: address, name: name)
    end
  end
end
