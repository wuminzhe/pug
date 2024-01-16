namespace :pug do
  # example:
  # rails "app:add_contract_abi[421_613,0x000000007e24da6666c773280804d8021e12e13f]"
  desc 'Add contract abi from explorer'
  task :add_contract_abi, %i[chain_id address] => :environment do |_t, args|
    chain_id = args[:chain_id].to_i
    address = args[:address]

    api = Etherscan.api(chain_id)
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
        # wrong abi here
        Pug::Trongrid.contract_abi(chain_id, address)
      else
        raise "Can not get contract abi from #{api.class}"
      end
    file = Pug.save(name, abi)
    puts "Saved abi file to #{file}"
  end

  # example:
  # rails "app:add_contract_abi_from_file[Relayer, /workspaces/pug/test/dummy/public/abis/Relayer.json]"
  desc 'Add contract abi from file'
  task :add_contract_abi_from_file, %i[name abi_file] => :environment do |_t, args|
    name = args[:name]
    abi = JSON.parse File.open(args[:abi_file]).read

    file = Pug.save(name, abi)
    puts "Saved abi file to #{file}"
  end

  desc 'List abis files'
  task list_abis: :environment do
    dir = "#{Rails.root}/public/abis"
    Dir.foreach(dir) do |filename|
      puts "#{File.stat("#{dir}/#{filename}").ctime} - #{dir}/#{filename}" if filename.end_with?('.json')
    end
  end
end
