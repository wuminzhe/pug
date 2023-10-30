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

      def command_exists?(command)
        system("command -v #{command} > /dev/null 2>&1")
      end

      # returns: [ok?, time_total]
      def rpc_ping(rpc)
        command_exists?('curl') || raise('curl not found, please install it first.')

        # 0.163253,1102
        result = `curl -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"net_version","params": [],"id":1}' -m 5 -w "%{time_total},%{size_download}" -s -o /dev/null #{rpc}`.strip

        time_total, size_download = result.split(',').map(&:to_f)

        if size_download.zero? # means unreachable
          [false, nil]
        else
          [true, time_total.to_f]
        end
      end

      # returns: [rpc, time_total]
      def fastest_rpc(rpc_list)
        rpc_list.map { |rpc| [rpc, rpc_ping(rpc)] } # ["https://...", [true, 0.163253]]
                .select { |_rpc, result| result[0] } # filter unreachable rpc
                .map { |rpc, result| [rpc, result[1]] } # ["https://...", 0.163253]
                .to_h
                .min_by { |_, v| v }
      end
    end
  end
end
