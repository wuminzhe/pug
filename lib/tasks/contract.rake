namespace :pug do
  desc 'List contracts'
  task list_contracts: :environment do
    Pug::EvmContract.all.each do |contract|
      puts "== chain_id: #{contract.network.chain_id}"
      contract.attributes.except('id', 'network_id').each do |k, v|
        print "   #{k}: "
        if v.is_a? Time
          puts v
        else
          p v
        end
      end
      puts "   cmd: rails \"fetch_logs[#{contract.network.chain_id},#{contract.address}]\""
    end
  end
end
