require 'bigdecimal'

module Pug
  module Base58
    ALPHABET = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz'.freeze
    BASE = ALPHABET.length

    def self.encode(num)
      return ALPHABET[0] if num == 0

      str = ''
      while num > 0
        str = ALPHABET[num % BASE] + str
        num /= BASE
      end
      str
    end

    def self.decode(str)
      num = 0
      str.each_char { |char| num = num * BASE + ALPHABET.index(char) }
      num
    end
  end
end
