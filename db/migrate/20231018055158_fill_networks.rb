class FillNetworks < ActiveRecord::Migration[7.1]
  def up
    require 'open-uri'
    require 'json'

    networks = JSON.parse(URI.open('https://chainid.network/chains_mini.json').read)
    networks.each do |network|
      Pug::Network.create(
        chain_id: network['chainId'],
        name: network['shortName'].underscore,
        display_name: network['name'],
        rpc_list: network['rpc'],
        scan_span: 5000
      )
    end
  end

  def down
    Pug::Network.delete_all
  end
end
