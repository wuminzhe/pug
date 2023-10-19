module Api
  class Subscan
    PANGOLIN_API = 'https://pangolin.api.subscan.io/api'.freeze
    PANGORO_API = 'https://pangoro.api.subscan.io/api'.freeze
    DARWINIA_API = 'https://darwinia.api.subscan.io/api'.freeze
    CRAB_API = 'https://crab.api.subscan.io/api'.freeze

    def self.pangolin(api_key = nil)
      Api::Subscan.new(PANGOLIN_API, api_key)
    end

    def self.pangoro(api_key = nil)
      Api::Subscan.new(PANGORO_API, api_key)
    end

    def self.darwinia(api_key = nil)
      Api::Subscan.new(DARWINIA_API, api_key)
    end

    def self.crab(api_key = nil)
      Api::Subscan.new(CRAB_API, api_key)
    end

    def initialize(url, api_key = nil)
      @url = url
      @api_key = api_key
    end

    def request(modvle, action, params)
      url = "#{@url}/scan/#{modvle}/#{action}"
      uri = URI(url)
      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true

      request = Net::HTTP::Post.new(uri)
      request['User-Agent'] = 'ormp client'
      request['Content-Type'] = 'application/json'
      request['X-API-Key'] = @api_key
      request.body = params.to_json

      response = https.request(request)
      raise response.body if response.code != '200'

      json_response = JSON.parse(response.body)

      if json_response.key?('status')
        raise json_response['message'] if json_response['status'] != '1'

        json_response['result'] || json_response['message']
      elsif json_response.key?('code') # normal response
        raise json_response['message'] if json_response['code'] != 0

        json_response['data']
      end
    end

    def respond_to_missing?(*_args)
      true
    end

    def method_missing(method, *args)
      # evm_contract
      modvle, action = method.to_s.split('_')

      request(modvle, action, args[0])
    end

    # forge flatten src/eco/Relayer.sol > ~/Downloads/Relayer.sol
    def evm_contract_verifysource(contract_name, contract_address, source_code)
      data = {
        apikey: @api_key,
        module: 'contract',
        action: 'verifysource',
        address: contract_address,
        contract_name: contract_name,
        source_code: source_code,
        sourceCode: source_code,
        optimize: true,
        optimization_runs: 200
      }
      request('evm', 'contract/verifysource', data)
    end

    def self.test
      client = Api::Subscan.pangolin(ENV['SUBSCAN_API_KEY'])
      # p client.evm_contract({ address: '0xeab1f01a8f4a2687023b159c2063639adad5304e' })

      name = 'Relayer'
      address = '0x000000007e24da6666c773280804d8021e12e13f'

      # file = File.join(File.dirname(__FILE__), 'sources', 'Relayer.sol')
      # code = File.open(file).read
      # remove all blank chars after lines
      # code = code.gsub(/(?<=\n)\s*/, '').gsub("\n", '')
      # p code
      # code = Base64.encode64(code)
      code = 'cHJhZ21hIHNvbGlkaXR5IDAuOC4xNzsKCnN0cnVjdCBNZXNzYWdlIHsKICAgIGFkZHJlc3MgY2hhbm5lbDsKICAgIHVpbnQyNTYgaW5kZXg7CiAgICB1aW50MjU2IGZyb21DaGFpbklkOwogICAgYWRkcmVzcyBmcm9tOwogICAgdWludDI1NiB0b0NoYWluSWQ7CiAgICBhZGRyZXNzIHRvOwogICAgYnl0ZXMgZW5jb2RlZDsgCn0KCnN0cnVjdCBDb25maWcgewogICAgYWRkcmVzcyBvcmFjbGU7CiAgICBhZGRyZXNzIHJlbGF5ZXI7Cn0KCmZ1bmN0aW9uIGhhc2goTWVzc2FnZSBtZW1vcnkgbWVzc2FnZSkgcHVyZSByZXR1cm5zIChieXRlczMyKSB7CiAgICByZXR1cm4ga2VjY2FrMjU2KGFiaS5lbmNvZGUobWVzc2FnZSkpOwp9CgppbnRlcmZhY2UgSUVuZHBvaW50IHsKICAgIGZ1bmN0aW9uIHNlbmQodWludDI1NiB0b0NoYWluSWQsIGFkZHJlc3MgdG8sIGJ5dGVzIGNhbGxkYXRhIGVuY29kZWQsIGJ5dGVzIGNhbGxkYXRhIHBhcmFtcykKICAgICAgICBleHRlcm5hbAogICAgICAgIHBheWFibGUKICAgICAgICByZXR1cm5zIChieXRlczMyKTsKCiAgICBmdW5jdGlvbiBmZWUodWludDI1NiB0b0NoYWluSWQsIGFkZHJlc3MsIC8qdG8qLyBieXRlcyBjYWxsZGF0YSBlbmNvZGVkLCBieXRlcyBjYWxsZGF0YSBwYXJhbXMpIGV4dGVybmFsIHZpZXc7CgogICAgZnVuY3Rpb24gY2xlYXJGYWlsZWRNZXNzYWdlKE1lc3NhZ2UgY2FsbGRhdGEgbWVzc2FnZSkgZXh0ZXJuYWw7CgogICAgZnVuY3Rpb24gcmV0cnlGYWlsZWRNZXNzYWdlKE1lc3NhZ2UgY2FsbGRhdGEgbWVzc2FnZSkgZXh0ZXJuYWwgcmV0dXJucyAoYm9vbCBkaXNwYXRjaFJlc3VsdCk7CgogICAgZnVuY3Rpb24gcmVjdihNZXNzYWdlIGNhbGxkYXRhIG1lc3NhZ2UsIGJ5dGVzIGNhbGxkYXRhIHByb29mLCB1aW50MjU2IGdhc0xpbWl0KQogICAgICAgIGV4dGVybmFsCiAgICAgICAgcmV0dXJucyAoYm9vbCBkaXNwYXRjaFJlc3VsdCk7CgogICAgZnVuY3Rpb24gcHJvdmUoKSBleHRlcm5hbCB2aWV3IHJldHVybnMgKGJ5dGVzMzJbMzJdIG1lbW9yeSk7CgogICAgZnVuY3Rpb24gZ2V0QXBwQ29uZmlnKGFkZHJlc3MgdWEpIGV4dGVybmFsIHZpZXcgcmV0dXJucyAoQ29uZmlnIG1lbW9yeSk7CgogICAgZnVuY3Rpb24gc2V0QXBwQ29uZmlnKGFkZHJlc3Mgb3JhY2xlLCBhZGRyZXNzIHJlbGF5ZXIpIGV4dGVybmFsOwoKICAgIGZ1bmN0aW9uIHNldERlZmF1bHRDb25maWcoYWRkcmVzcyBvcmFjbGUsIGFkZHJlc3MgcmVsYXllcikgZXh0ZXJuYWw7CiAgICBmdW5jdGlvbiBkZWZhdWx0Q29uZmlnKCkgZXh0ZXJuYWwgdmlldyByZXR1cm5zIChDb25maWcgbWVtb3J5KTsKICAgIGZ1bmN0aW9uIGNoYW5nZVNldHRlcihhZGRyZXNzIHNldHRlcl8pIGV4dGVybmFsOwp9Cgpjb250cmFjdCBSZWxheWVyIHsKICAgIGV2ZW50IEFzc2lnbmVkKGJ5dGVzMzIgaW5kZXhlZCBtc2dIYXNoLCB1aW50MjU2IGZlZSwgYnl0ZXMgcGFyYW1zLCBieXRlczMyWzMyXSBwcm9vZik7CiAgICBldmVudCBTZXREc3RQcmljZSh1aW50MjU2IGluZGV4ZWQgY2hhaW5JZCwgdWludDEyOCBkc3RQcmljZVJhdGlvLCB1aW50MTI4IGRzdEdhc1ByaWNlSW5XZWkpOwogICAgZXZlbnQgU2V0RHN0Q29uZmlnKHVpbnQyNTYgaW5kZXhlZCBjaGFpbklkLCB1aW50NjQgYmFzZUdhcywgdWludDY0IGdhc1BlckJ5dGUpOwogICAgZXZlbnQgU2V0QXBwcm92ZWQoYWRkcmVzcyBvcGVyYXRvciwgYm9vbCBhcHByb3ZlKTsKCiAgICBzdHJ1Y3QgRHN0UHJpY2UgewogICAgICAgIHVpbnQxMjggZHN0UHJpY2VSYXRpbzsgCiAgICAgICAgdWludDEyOCBkc3RHYXNQcmljZUluV2VpOwogICAgfQoKICAgIHN0cnVjdCBEc3RDb25maWcgewogICAgICAgIHVpbnQ2NCBiYXNlR2FzOwogICAgICAgIHVpbnQ2NCBnYXNQZXJCeXRlOwogICAgfQoKICAgIGFkZHJlc3MgcHVibGljIGltbXV0YWJsZSBQUk9UT0NPTDsKICAgIGFkZHJlc3MgcHVibGljIG93bmVyOwoKICAgIG1hcHBpbmcodWludDI1NiA9PiBEc3RQcmljZSkgcHVibGljIHByaWNlT2Y7CiAgICBtYXBwaW5nKHVpbnQyNTYgPT4gRHN0Q29uZmlnKSBwdWJsaWMgY29uZmlnT2Y7CiAgICBtYXBwaW5nKGFkZHJlc3MgPT4gYm9vbCkgcHVibGljIGFwcHJvdmVkT2Y7CgogICAgbW9kaWZpZXIgb25seU93bmVyKCkgewogICAgICAgIHJlcXVpcmUobXNnLnNlbmRlciA9PSBvd25lciwgIiFvd25lciIpOwogICAgICAgIF87CiAgICB9CgogICAgbW9kaWZpZXIgb25seUFwcHJvdmVkKCkgewogICAgICAgIHJlcXVpcmUoaXNBcHByb3ZlZChtc2cuc2VuZGVyKSwgIiFhcHByb3ZlIik7CiAgICAgICAgXzsKICAgIH0KCiAgICBjb25zdHJ1Y3RvcihhZGRyZXNzIGRhbywgYWRkcmVzcyBvcm1wKSB7CiAgICAgICAgUFJPVE9DT0wgPSBvcm1wOwogICAgICAgIG93bmVyID0gZGFvOwogICAgfQoKICAgIHJlY2VpdmUoKSBleHRlcm5hbCBwYXlhYmxlIHt9CgogICAgZnVuY3Rpb24gY2hhbmdlT3duZXIoYWRkcmVzcyBvd25lcl8pIGV4dGVybmFsIG9ubHlPd25lciB7CiAgICAgICAgb3duZXIgPSBvd25lcl87CiAgICB9CgogICAgZnVuY3Rpb24gaXNBcHByb3ZlZChhZGRyZXNzIG9wZXJhdG9yKSBwdWJsaWMgdmlldyByZXR1cm5zIChib29sKSB7CiAgICAgICAgcmV0dXJuIGFwcHJvdmVkT2Zbb3BlcmF0b3JdOwogICAgfQoKICAgIGZ1bmN0aW9uIHNldEFwcHJvdmVkKGFkZHJlc3Mgb3BlcmF0b3IsIGJvb2wgYXBwcm92ZSkgcHVibGljIG9ubHlPd25lciB7CiAgICAgICAgYXBwcm92ZWRPZltvcGVyYXRvcl0gPSBhcHByb3ZlOwogICAgICAgIGVtaXQgU2V0QXBwcm92ZWQob3BlcmF0b3IsIGFwcHJvdmUpOwogICAgfQoKICAgIGZ1bmN0aW9uIHNldERzdFByaWNlKHVpbnQyNTYgY2hhaW5JZCwgdWludDEyOCBkc3RQcmljZVJhdGlvLCB1aW50MTI4IGRzdEdhc1ByaWNlSW5XZWkpIGV4dGVybmFsIG9ubHlBcHByb3ZlZCB7CiAgICAgICAgcHJpY2VPZltjaGFpbklkXSA9IERzdFByaWNlKGRzdFByaWNlUmF0aW8sIGRzdEdhc1ByaWNlSW5XZWkpOwogICAgICAgIGVtaXQgU2V0RHN0UHJpY2UoY2hhaW5JZCwgZHN0UHJpY2VSYXRpbywgZHN0R2FzUHJpY2VJbldlaSk7CiAgICB9CgogICAgZnVuY3Rpb24gc2V0RHN0Q29uZmlnKHVpbnQyNTYgY2hhaW5JZCwgdWludDY0IGJhc2VHYXMsIHVpbnQ2NCBnYXNQZXJCeXRlKSBleHRlcm5hbCBvbmx5QXBwcm92ZWQgewogICAgICAgIGNvbmZpZ09mW2NoYWluSWRdID0gRHN0Q29uZmlnKGJhc2VHYXMsIGdhc1BlckJ5dGUpOwogICAgICAgIGVtaXQgU2V0RHN0Q29uZmlnKGNoYWluSWQsIGJhc2VHYXMsIGdhc1BlckJ5dGUpOwogICAgfQoKICAgIGZ1bmN0aW9uIHdpdGhkcmF3KGFkZHJlc3MgdG8sIHVpbnQyNTYgYW1vdW50KSBleHRlcm5hbCBvbmx5QXBwcm92ZWQgewogICAgICAgIChib29sIHN1Y2Nlc3MsKSA9IHRvLmNhbGx7dmFsdWU6IGFtb3VudH0oIiIpOwogICAgICAgIHJlcXVpcmUoc3VjY2VzcywgIiF3aXRoZHJhdyIpOwogICAgfQoKICAgIGZ1bmN0aW9uIGZlZSh1aW50MjU2IHRvQ2hhaW5JZCwgYWRkcmVzcywgLyp1YSovIHVpbnQyNTYgc2l6ZSwgYnl0ZXMgY2FsbGRhdGEgcGFyYW1zKQogICAgICAgIHB1YmxpYwogICAgICAgIHZpZXcKICAgICAgICByZXR1cm5zICh1aW50MjU2KQogICAgewogICAgICAgIHVpbnQyNTYgZXh0cmFHYXMgPSBhYmkuZGVjb2RlKHBhcmFtcywgKHVpbnQyNTYpKTsKICAgICAgICBEc3RQcmljZSBtZW1vcnkgcCA9IHByaWNlT2ZbdG9DaGFpbklkXTsKICAgICAgICBEc3RDb25maWcgbWVtb3J5IGMgPSBjb25maWdPZlt0b0NoYWluSWRdOwoKICAgICAgICB1aW50MjU2IHJlbW90ZVRva2VuID0gcC5kc3RHYXNQcmljZUluV2VpICogKGMuYmFzZUdhcyArIGV4dHJhR2FzKTsKICAgICAgICB1aW50MjU2IHNvdXJjZVRva2VuID0gcmVtb3RlVG9rZW4gKiBwLmRzdFByaWNlUmF0aW8gLyAoMTAgKiogMTApOwogICAgICAgIHVpbnQyNTYgcGF5bG9hZFRva2VuID0gYy5nYXNQZXJCeXRlICogc2l6ZSAqIHAuZHN0R2FzUHJpY2VJbldlaSAqIHAuZHN0UHJpY2VSYXRpbyAvICgxMCAqKiAxMCk7CiAgICAgICAgcmV0dXJuIHNvdXJjZVRva2VuICsgcGF5bG9hZFRva2VuOwogICAgfQoKICAgIGZ1bmN0aW9uIGFzc2lnbihieXRlczMyIG1zZ0hhc2gsIGJ5dGVzIGNhbGxkYXRhIHBhcmFtcykgZXh0ZXJuYWwgcGF5YWJsZSB7CiAgICAgICAgcmVxdWlyZShtc2cuc2VuZGVyID09IFBST1RPQ09MLCAiIW9ybXAiKTsKICAgICAgICBlbWl0IEFzc2lnbmVkKG1zZ0hhc2gsIG1zZy52YWx1ZSwgcGFyYW1zLCBJRW5kcG9pbnQoUFJPVE9DT0wpLnByb3ZlKCkpOwogICAgfQoKICAgIGZ1bmN0aW9uIHJlbGF5KE1lc3NhZ2UgY2FsbGRhdGEgbWVzc2FnZSwgYnl0ZXMgY2FsbGRhdGEgcHJvb2YsIHVpbnQyNTYgZ2FzTGltaXQpIGV4dGVybmFsIG9ubHlBcHByb3ZlZCB7CiAgICAgICAgSUVuZHBvaW50KFBST1RPQ09MKS5yZWN2KG1lc3NhZ2UsIHByb29mLCBnYXNMaW1pdCk7CiAgICB9Cn0KCg=='

      p client.evm_contract_verifysource(name, address, code)
    end
  end
end

# Api::Subscan.pangolin.evm_contract({address: "0x000000007e24da6666c773280804d8021e12e13f"})
