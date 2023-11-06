# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2023_11_06_025503) do
  create_table "pug_evm_contracts", force: :cascade do |t|
    t.integer "network_id"
    t.string "address"
    t.string "name"
    t.string "abi_file"
    t.string "creator"
    t.integer "creation_block"
    t.string "creation_tx_hash"
    t.datetime "creation_timestamp"
    t.integer "last_scanned_block"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["network_id", "address"], name: "index_pug_evm_contracts_on_network_id_and_address", unique: true
  end

  create_table "pug_evm_logs", force: :cascade do |t|
    t.integer "network_id"
    t.integer "evm_contract_id"
    t.string "address"
    t.text "data"
    t.string "block_hash"
    t.integer "block_number"
    t.string "transaction_hash"
    t.integer "transaction_index"
    t.integer "log_index"
    t.datetime "timestamp"
    t.string "topic0"
    t.string "topic1"
    t.string "topic2"
    t.string "topic3"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["network_id", "block_number", "transaction_index", "log_index"], name: "idx_on_network_id_block_number_transaction_index_lo_603ca303c9", unique: true
    t.index ["topic0"], name: "index_pug_evm_logs_on_topic0"
    t.index ["topic1"], name: "index_pug_evm_logs_on_topic1"
    t.index ["topic2"], name: "index_pug_evm_logs_on_topic2"
    t.index ["topic3"], name: "index_pug_evm_logs_on_topic3"
  end

  create_table "pug_evm_transactions", force: :cascade do |t|
    t.integer "evm_contract_id"
    t.integer "network_id"
    t.string "block_hash"
    t.string "block_number"
    t.string "chain_id"
    t.string "from"
    t.string "to"
    t.string "value"
    t.string "gas"
    t.string "gas_price"
    t.string "transaction_hash"
    t.text "input"
    t.string "max_priority_fee_per_gas"
    t.string "max_fee_per_gas"
    t.string "nonce"
    t.string "r"
    t.string "s"
    t.string "v"
    t.string "transaction_index"
    t.string "type"
  end

  create_table "pug_networks", force: :cascade do |t|
    t.bigint "chain_id"
    t.string "name"
    t.string "display_name"
    t.string "rpc"
    t.string "explorer"
    t.integer "scan_span", default: 2000
    t.integer "last_scanned_block", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

end
