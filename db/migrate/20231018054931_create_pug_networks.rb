class CreatePugNetworks < ActiveRecord::Migration[7.1]
  def change
    create_table :pug_networks do |t|
      t.integer :chain_id
      t.string :name
      t.string :display_name
      t.json :rpc_list
      t.integer :scan_span

      t.timestamps
    end
  end
end
