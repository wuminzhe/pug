class FillPugNetworks < ActiveRecord::Migration[7.1]
  def up
    require 'open-uri'

    networks = JSON.parse(URI.open('https://chainid.network/chains_mini.json').read)
    ActiveRecord::Base.transaction do
      networks.each do |network|
        Pug::Network.create(
          chain_id: network['chainId'],
          name: network['shortName'].underscore,
          display_name: network['name'],
          rpc: Pug.filter_rpc_list(network['rpc'])&.first,
          scan_span: 5000
        )
      end
    end
  end

  def down
    Pug::Network.delete_all
  end
end
