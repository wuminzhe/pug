# https://docs.infura.io/networks/ethereum/json-rpc-methods
module Api
  class RpcClient
    # build EvmTrackHelper instance
    def initialize(url)
      @client = Eth::Client::Http.new(url)
    end

    attr_reader :client

    delegate :call, to: :@client
    delegate :transact_and_wait, to: :@client

    def respond_to_missing?(*_args)
      true
    end

    def method_missing(method, *args)
      resp = client.send(method, *args)
      raise resp['error']['message'] if resp['error']

      resp['result']
    end

    def latest_block_number
      client.eth_block_number['result'].to_i(16) - 12
    end

    def get_block_by_number(number)
      block = client.eth_get_block_by_number(number, true)['result']
      return if block.nil?

      block['number'] = block['number'].to_i(16)
      block
    end

    def get_latest_block
      start = Time.now
      block = get_block_by_number(latest_block_number)
      time_elapsed = Time.now - start
      puts "time elapsed: #{time_elapsed} ms"
      block
    end

    def track_block(start_from_block = nil)
      last_tracked_block =
        (
          if start_from_block.nil?
            get_latest_block
          else
            get_block_by_number(start_from_block)
          end
        )

      loop do
        block_number_to_track = last_tracked_block['number'] + 1

        # run too fast, sleep ns and retry
        if block_number_to_track > latest_block_number
          seconds_to_sleep = 5
          # puts "run too fast, sleep #{seconds_to_sleep}s and retry"
          sleep seconds_to_sleep
          next
        end

        new_block = get_block_by_number(block_number_to_track)

        # do something with new_block
        puts "new block: #{new_block['number']}"
        yield new_block

        # update last_tracked_block
        last_tracked_block = new_block
      rescue StandardError => e
        puts "error: #{e}"
      end
    end

    def get_transactions(block, to, method_id)
      raise 'Wrong method id' if method_id.length != 10

      block['transactions'].select do |tx|
        tx['to'] == to.downcase && tx['input'].start_with?(method_id.downcase)
      end
    end

    # tx attributes: [
    #   "blockHash",
    #   "blockNumber",
    #   "hash",
    #   "accessList",
    #   "chainId",
    #   "from",
    #   "gas",
    #   "gasPrice",
    #   "input",
    #   "maxFeePerGas",
    #   "maxPriorityFeePerGas",
    #   "nonce",
    #   "r",
    #   "s",
    #   "to",
    #   "transactionIndex",
    #   "type",
    #   "v",
    #   "value"
    # ]
    # method_id: selector, for example: 0x8f0e6d6b
    def track_transactions(to, method_id, start_from_block = nil, &block)
      track_block(start_from_block) do |new_block|
        transactions = get_transactions(new_block, to, method_id)
        transactions.each(&block)
      end
    end

    # A transaction with a log with topics [A, B] will be matched by the following topic filters:
    #   [] “anything”
    #   [A] “A in first position (and anything after)”
    #   [null, B] “anything in first position AND B in second position (and anything after)”
    #   [A, B] “A in first position AND B in second position (and anything after)”
    #   [[A, B], [A, B]] “(A OR B) in first position AND (A OR B) in second position (and anything after)”
    #
    # From: https://docs.alchemy.com/docs/deep-dive-into-eth_getlogs
    def get_logs(addresses, topics, from_block, block_interval)
      to_block = [(from_block + block_interval - 1), latest_block_number].min

      if to_block > from_block
        [
          get_logs_between(addresses, topics, from_block, to_block),
          to_block
        ]
      else
        [
          [],
          from_block - 1
        ]
      end
    end

    def get_logs_between(addresses, topics, from_block, to_block)
      logs = []

      resp =
        if topics.nil?
          client.eth_get_logs(
            {
              address: addresses,
              from_block: to_hex(from_block),
              to_block: to_hex(to_block)
            }
          )
        else
          client.eth_get_logs(
            {
              address: addresses,
              topics: [topics],
              from_block: to_hex(from_block),
              to_block: to_hex(to_block)
            }
          )
        end
      raise resp['error'].to_json if resp['error']

      (logs + resp['result']).map { |log| rich(log) }
    end

    # 从 Ethereum 获取事件日志
    def get_event_logs(address, event_signatures, from_block, block_interval)
      to_block = [(from_block + block_interval - 1), latest_block_number].min
      return [] if to_block < from_block

      logs = []

      resp =
        client.eth_get_logs(
          {
            address:,
            topics: [event_signatures],
            from_block: to_hex(from_block),
            to_block: to_hex(to_block)
          }
        )
      raise resp['error'].to_json if resp['error']

      (logs + resp['result']).map { |log| rich(log) }
    end

    private

    # result example:
    # [
    #   {
    #     "address"=>"0x000000007e24da6666c773280804d8021e12e13f",
    #     "topics"=>["0xd984ea421ae5d2a473199f85e03998a04a12f54d6f1fa183a955b3df1c0c546d"],
    #     "data"=>"0x0000000000000000000000000b001c95e86d64c1ad6e43944c568a6c31b538870000000000000000000000000000000000000000000000000000000000000001",
    #     "block_hash"=>"0xdf64b1e453e8e1ccf37bfcee435ccc300d33155675db9d653506dd48d15f686f",
    #     "block_number"=>1367206,
    #     "transaction_hash"=>"0x3c9c9c70cb7f451edd8d57bb68f901f7943c46afab512f3a157f26fe7412c48a",
    #     "transaction_index"=>5,
    #     "log_index"=>2,
    #     "transaction_log_index"=>"0x0",
    #     "removed"=>false,
    #     "timestamp"=>1693364784
    #   }
    # ]
    def rich(log)
      # convert hex to decimal
      log['blockNumber'] = log['blockNumber'].to_i(16)
      log['transactionIndex'] = log['transactionIndex'].to_i(16)
      log['logIndex'] = log['logIndex'].to_i(16)

      # add timestamp to log
      block = get_block_by_number(log['blockNumber'])
      log['timestamp'] = block['timestamp'].to_i(16)

      log.transform_keys(&:underscore)
    end

    def to_hex(number)
      '0x' + number.to_s(16)
    end
  end
end

# contract_address = '0x000000007e24da6666c773280804d8021e12e13f'
# rpc = 'https://arbitrum-goerli.publicnode.com'
# # rpc = 'https://rpc.darwinia.network'
#
# client = Client::RpcClient.new(rpc)
# p client.eth_block_number
