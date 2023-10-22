# from https://github.com/rubycocos/blockchain/tree/master/Abicoder
module Pug
  module Abicoder
    ###################
    ### some (shared) constants  (move to constants.rb or such - why? why not?)

    ## todo/check:  use auto-freeze string literals magic comment - why? why not?
    ##
    ## todo/fix: move  BYTE_EMPTY, BYTE_ZERO, BYTE_ONE to upstream to bytes gem
    ##    and make "global" constants - why? why not?

    ## BYTE_EMPTY = "".b.freeze
    BYTE_ZERO  = "\x00".b.freeze
    BYTE_ONE   = "\x01".b.freeze ## note: used for encoding bool for now

    UINT_MAX = 2**256 - 1   ## same as 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    UINT_MIN = 0
    INT_MAX  = 2**255 - 1   ## same as  57896044618658097711785492504343953926634992332820282019728792003956564819967
    INT_MIN  = -2**255      ## same as -57896044618658097711785492504343953926634992332820282019728792003956564819968
  end # module Abicoder
end

require_relative 'abicoder/types'
require_relative 'abicoder/parser'

require_relative 'abicoder/encoder'
require_relative 'abicoder/decoder'

module Pug
  module Abicoder
    def self.encoder
      @encoder ||= Encoder.new
    end

    def self.decoder
      @decoder ||= Decoder.new
    end

    def self.encode(types, args)
      encoder.encode(types, args)
    end

    def self.decode(types, data, raise_errors = false)
      decoder.decode(types, data, raise_errors)
    end

    ## add alternate _abi names  - why? why not?
    class << self
      alias encode_abi encode
      alias decode_abi decode
    end
  end ## module Abicoder
end

class String
  ## add bin_to_hex helper method
  ##   note: String#hex already in use (is an alias for String#to_i(16) !!)
  def hexdigest
    unpack1('H*')
  end
end

def hex(hex) # convert hex(adecimal) string  to binary string
  if %w[0x 0X].include?(hex[0, 2]) ## cut-of leading 0x or 0X if present
    [hex[2..-1]].pack('H*')
  else
    [hex].pack('H*')
  end
end

# types = ['bytes32', '(address,uint256,uint256,address,uint256,address,bytes)']
# data = hex 'fc2a07bae9b75d5a817aa5ff752d263d213286dda48387a2e818814f4557d612' +
#            '0000000000000000000000000000000000000000000000000000000000000040' +
#            '0000000000000000000000000000000000bd9dcfda5c60697039e2b3b28b079b' +
#            '0000000000000000000000000000000000000000000000000000000000000001' +
#            '0000000000000000000000000000000000000000000000000000000000066eed' +
#            '0000000000000000000000000f14341a7f464320319025540e8fe48ad0fe5aec' +
#            '000000000000000000000000000000000000000000000000000000000000002b' +
#            '0000000000000000000000000000000000bd9dcfda5c60697039e2b3b28b079b' +
#            '00000000000000000000000000000000000000000000000000000000000000e0' +
#            '0000000000000000000000000000000000000000000000000000000000000000'
# pp Abicoder.decode(types, data)
