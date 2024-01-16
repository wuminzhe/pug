namespace :pug do
  desc 'List networks'
  task list_networks: :environment do
    list = Pug::Network.all.map do |network|
      "#{network.chain_id}, #{network.name}, #{network.display_name}"
    end.join("\n")
    result = `echo "#{list}" | fzf`
    next if result.blank?

    chain_id = result.split(',')[0].strip
    network = Pug::Network.find_by(chain_id:)

    network.attributes.except('id').each do |k, v|
      print "#{k}: "
      if v.is_a? Time
        puts v
      else
        p v
      end
    end
  end

  desc "Reset networks' last_scanned_block"
  task reset_scan_cursor: :environment do
    Pug::EvmContract.all.each do |contract|
      if contract.creation_block < contract.network.last_scanned_block
        contract.network.update!(last_scanned_block: contract.creation_block)
        puts "chain_id: #{contract.network.chain_id}, reset last_scanned_block to #{contract.creation_block}"
      end
    end
  end
end
