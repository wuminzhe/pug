class CreatePugEvmTransactions < ActiveRecord::Migration[7.1]
  def change
    create_table :pug_evm_transactions do |t|
      t.integer :evm_contract_id
      t.integer :network_id
      t.string :block_hash
      t.string :block_number
      t.string :chain_id
      t.string :from
      t.string :to
      t.string :value
      t.string :gas
      t.string :gas_price
      t.string :transaction_hash
      t.text :input
      t.string :max_priority_fee_per_gas
      t.string :max_fee_per_gas
      t.string :nonce
      t.string :r
      t.string :s
      t.string :v
      t.string :transaction_index
      t.string :transaction_type
    end

    add_index :pug_evm_transactions, %i[network_id transaction_hash], unique: true

    add_column :pug_evm_logs, :evm_transaction_id, :integer
  end
end
