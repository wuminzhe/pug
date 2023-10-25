module Pug
  module Utils
    class << self
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
    end
  end
end
