class FillPugNetworks < ActiveRecord::Migration[7.1]
  def up
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
          scan_span: 5000
        )
      end
    end
  end

  def down
    Pug::Network.delete_all
  end
end
