namespace :pug do
  # example:
  # rails "app:add_contract_abi[421_613,0x000000007e24da6666c773280804d8021e12e13f]"
  desc 'Add contract abi from a verified contract on etherscan'
  task :add_contract_abi, %i[chain_id address] => :environment do |_t, args|
    chain_id = args[:chain_id]
    address = args[:address]

    name, abi = Pug.get_contract_abi_from_explorer(chain_id, address)
    file = Pug.save(name, abi)
  end

  # example:
  # rails "app:add_contract_abi_from_file[Relayer, /workspaces/pug/test/dummy/public/abis/Relayer-b47bf80ce9.json]"
  desc 'Add contract abi from file'
  task :add_contract_abi_from_file, %i[name abi_file] => :environment do |_t, args|
    name = args[:name]
    abi = JSON.parse File.open(args[:abi_file]).read

    file = Pug.save(name, abi)
  end

  desc 'List abis files'
  task list_abis: :environment do
    dir = "#{Rails.root}/public/abis"
    Dir.foreach(dir) do |filename|
      puts "#{File.stat("#{dir}/#{filename}").ctime} - #{dir}/#{filename}" if filename.end_with?('.json')
    end
  end
end
