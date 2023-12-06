module Pug
  module ContractInfo
    class << self
      def creation_info(network, address)
        api = Etherscan.api(network.name, ENV['ETHERSCAN_API_KEY'])

        if api.is_a?(Subscan::Api)
          data = api.evm_contract(address:)
          raise "Contract with address #{address} not found on subscan" if data.blank?

          {
            creator: data['deployer'],
            tx_hash: data['transaction_hash'],
            block: data['block_num'],
            timestamp: Time.at(data['deploy_at'])
          }
        elsif api.is_a?(Etherscan::Api)
          data = api.contract_getcontractcreation(contractaddresses: address)
          raise "Contract with address #{address} not found on etherscan" if data.empty?

          # TODO: check the rpc is available
          client = JsonRpcClient.new(network.rpc)
          creation_block = client.eth_get_transaction_by_hash(data[0]['txHash'])['blockNumber'].to_i(16)
          creation_timestamp = client.get_block_by_number(creation_block)['timestamp'].to_i(16)

          {
            creator: data[0]['contractCreator'],
            tx_hash: data[0]['txHash'],
            block: creation_block,
            timestamp: Time.at(creation_timestamp)
          }
        elsif api.is_a?(Tronscan::Api)
          Trongrid.contract_creation_info(network.chain_id, address)
        else
          raise 'Not supported'
        end
      end

      def contract_abi(chain_id, address)
        network_name = Pug::Network.find_by(chain_id:).name
        raise "Network with chain_id #{chain_id} not found" if network_name&.nil?

        api = Etherscan.api(network_name, ENV['ETHERSCAN_API_KEY'])
        abi, name =
          if api.is_a?(Etherscan::Api)
            result = api.contract_getsourcecode(address:)[0]
            [
              JSON.parse(result['ABI']),
              result['ContractName']
            ]
          elsif api.is_a?(Subscan::Api)
            raise 'Not supported yet for subscan'
          elsif api.is_a?(Tronscan::Api)
            Trongrid.contract_abi(chain_id, address)
          else
            raise "Can not get contract abi from #{api.class}"
          end

        [name, abi]
      end
    end
  end

  module Trongrid
    class << self
      # https://docs.particle.network/developers/other-services/node-service/evm-chains-api
      def contract_abi(chain_id, address)
        if chain_id == 2_494_104_990
          url = URI('https://api.shasta.trongrid.io/wallet/getcontract')
        elsif chain_id == 3_448_148_188
          url = URI('https://nile.trongrid.io/wallet/getcontract')
        elsif chain_id == 728_126_428
          url = URI('https://api.trongrid.io/wallet/getcontract')
        else
          raise "Not supported chain_id #{chain_id}"
        end

        http = Net::HTTP.new(url.host, url.port)
        http.use_ssl = true

        request = Net::HTTP::Post.new(url)
        request['accept'] = 'application/json'
        request['content-type'] = 'application/json'
        request.body = '{"value":"' + address + '","visible":true}'

        response = http.request(request)
        result = JSON.parse response.body
        [result['abi']['entrys'], result['name']]
      end

      # curl --request GET \
      #   --url 'https://nile.trongrid.io/v1/contracts/TX4YnjwVQncmVLrwtfvLpauYJmyK6Qc2Rv/transactions?order_by=block_timestamp%2Casc&limit=1' \
      #   --header 'accept: application/json'
      def contract_creation_info(chain_id, address)
        path = "v1/contracts/#{address}/transactions?order_by=block_timestamp%2Casc&limit=1"

        url =
          if chain_id == 2_494_104_990
            URI("https://api.shasta.trongrid.io/#{path}")
          elsif chain_id == 3_448_148_188
            URI("https://nile.trongrid.io/#{path}")
          elsif chain_id == 728_126_428
            URI("https://api.trongrid.io/#{path}")
          else
            raise "Not supported chain_id #{chain_id}"
          end

        http = Net::HTTP.new(url.host, url.port)
        http.use_ssl = true

        request = Net::HTTP::Get.new(url)
        request['accept'] = 'application/json'

        response = http.request(request)
        result = JSON.parse response.body
        {
          creator: '0x' + result['data'][0]['raw_data']['contract'][0]['parameter']['value']['owner_address'],
          tx_hash: '0x' + result['data'][0]['txID'],
          block: result['data'][0]['blockNumber'],
          timestamp: Time.at(result['data'][0]['block_timestamp'].to_i / 1000)
          # name: result['data'][0]['raw_data']['contract'][0]['parameter']['value']['new_contract']['name'],
          # abi: result['data'][0]['raw_data']['contract'][0]['parameter']['value']['new_contract']['abi']['entrys']
        }
      end
    end
  end
end
