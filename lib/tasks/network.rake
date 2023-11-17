namespace :pug do
  desc 'Fill networks'
  task fill_networks: :environment do
    require 'open-uri'
    networks = JSON.parse(URI.open('https://chainid.network/chains.json').read)
    ActiveRecord::Base.transaction do
      networks.each do |network|
        rpc = network['rpc']&.select { |url| url.start_with?('http') && url !~ /\$\{(.+)\}/ }&.first
        explorer = network['explorers']&.first&.[]('url')
        Pug::Network.create(
          chain_id: network['chainId'],
          name: network['shortName'].underscore,
          display_name: network['name'],
          rpc:,
          explorer:,
          scan_span: 2000
        )
      end
    end
  end

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

  desc 'Update network rpc'
  task update_rpc: :environment do
    loop do
      fastest_rpcs = Pug.active_networks_fastest_rpc
      fastest_rpcs.each do |chain_id, rpc, _|
        next unless rpc.present?

        network = Pug::Network.find_by(chain_id:)
        if network.rpc != rpc
          network.update!(rpc:)
          puts "#{network.display_name}'s rpc updated to: `#{rpc}`"
        else
          puts "#{network.display_name}'s rpc is already the fastest: `#{rpc}`"
        end
      end

      sleep 60
    rescue StandardError => e
      puts e.message
      puts e.backtrace.join("\n") unless e.message.include? 'timeout'
      sleep 60
    end
  end
end
