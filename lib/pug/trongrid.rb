module Pug
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
    end
  end
end
