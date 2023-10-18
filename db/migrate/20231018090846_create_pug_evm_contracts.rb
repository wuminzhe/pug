class CreatePugEvmContracts < ActiveRecord::Migration[7.1]
  def change
    create_table :pug_evm_contracts do |t|
      t.integer :network_id
      t.string :address
      t.string :abi_file
      t.string :creator
      t.integer :creation_block
      t.string :creation_tx_hash

      t.timestamps
    end
  end
end
