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

      # param example 1:
      #   ['root', 'bytes32']
      #   =>
      #   [["root", "bytes32"]]
      # param example 2:
      #   ["message", [["channel", "address"], ["index", "uint256"], ["fromChainId", "uint256"], ["from", "address"], ["toChainId", "uint256"], ["to", "address"], ["encoded", "bytes"]]]
      #   =>
      #   [["message_channel", "address"], ["message_index", "uint256"], ["message_fromChainId", "uint256"], ["message_from", "address"], ["message_toChainId", "uint256"], ["message_to", "address"], ["message_encoded", "bytes"]]
      def flat(prefix, param)
        param_name, param_content = param
        param_name = param_name.underscore

        if param_content.is_a?(String)
          return [[param_name, param_content]] if prefix.nil?

          [["#{prefix}_#{param_name}", param_content]]
        elsif param_content.is_a?(Array)
          result = []
          param_content.each do |inner_param|
            result += if prefix.nil?
                        flat(param_name, inner_param)
                      else
                        flat("#{prefix}_#{param_name}", inner_param)
                      end
          end
          result
        end
      end
    end
  end
end
