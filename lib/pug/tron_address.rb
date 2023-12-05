require_relative 'base58'

module Pug
  module TronAddress
    def self.tron_address?(address)
      address.start_with?('T') && address.length == 34
    end

    def self.base58check_to_hex(address)
      decoded = Base58.decode address
      decoded.to_s(16)[2...-8]
    end
  end
end
