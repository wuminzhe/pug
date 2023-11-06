# == Schema Information
#
# Table name: pug_evm_transactions
#
#  id                       :integer          not null, primary key
#  evm_contract_id          :integer
#  network_id               :integer
#  block_hash               :string
#  block_number             :string
#  chain_id                 :string
#  from                     :string
#  to                       :string
#  value                    :string
#  gas                      :string
#  gas_price                :string
#  transaction_hash         :string
#  input                    :text
#  max_priority_fee_per_gas :string
#  max_fee_per_gas          :string
#  nonce                    :string
#  r                        :string
#  s                        :string
#  v                        :string
#  transaction_index        :string
#  type                     :string
#
module Pug
  class EvmTransaction < ApplicationRecord
    belongs_to :network
    belongs_to :evm_contract
  end
end
