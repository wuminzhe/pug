require 'uri'
require 'net/http'
require 'json'

module Api
  # https://docs.etherscan.io/
  class Etherscan
    ETHERSCAN_API = 'https://api.etherscan.io/api'.freeze
    ARBITRUM_GOERLI_API = 'https://api-goerli.arbiscan.io/api'.freeze
    ARBITRUM_SEPOLIA_API = 'https://api-sepolia.arbiscan.io/api'.freeze
    ARBITRUM_ONE_API = 'https://api.arbiscan.io/api'.freeze

    def self.eth(api_key = nil)
      Api::Etherscan.new(ETHERSCAN_API, api_key)
    end

    def self.arb_goerli(api_key = nil)
      Api::Etherscan.new(ARBITRUM_GOERLI_API, api_key)
    end

    def self.arb_sep(api_key = nil)
      Api::Etherscan.new(ARBITRUM_SEPOLIA_API, api_key)
    end

    def self.arb1(api_key = nil)
      Api::Etherscan.new(ARBITRUM_ONE_API, api_key)
    end

    def initialize(url, api_key = nil)
      @url = url
      @api_key = api_key
    end

    def respond_to_missing?(*_args)
      true
    end

    def method_missing(method, *args)
      modvle, action = method.to_s.split('_')

      params = args[0]
      params_query = params.keys.map { |key| "#{key}=#{params[key]}" }.join('&')

      uri = URI "#{@url}?module=#{modvle}&action=#{action}&#{params_query}&apikey=#{@api_key}"
      resp = JSON.parse(Net::HTTP.get(uri))
      raise resp['result'] if resp['status'] == '0'

      resp['result']
    end

    def extract_contract_abi(address)
      result = contract_getsourcecode({ address: })[0]

      abi = JSON.parse result['ABI']
      name = result['ContractName']
      { contract_name: name, abi: }
    end
  end
end

# contract_address = '0x000000007e24da6666c773280804d8021e12e13f'
# api = Api::Etherscan.arb_goerli

# source
# result = JSON.parse api.contract_getsourcecode({ address: contract_address })[0]['SourceCode'][1..-2]
# p result

# result = api.extract_contract_abi(contract_address)
# p result

# p api.contract_getabi({ address: contract_address })
# p api.contract_getcontractcreation({ contractaddresses: contract_address })
