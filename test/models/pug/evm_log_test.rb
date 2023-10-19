# == Schema Information
#
# Table name: pug_evm_logs
#
#  id                :integer          not null, primary key
#  network_id        :integer
#  evm_contract_id   :integer
#  address           :string
#  data              :text
#  block_hash        :string
#  block_number      :integer
#  transaction_hash  :string
#  transaction_index :integer
#  log_index         :integer
#  timestamp         :datetime
#  topic0            :string
#  topic1            :string
#  topic2            :string
#  topic3            :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
require "test_helper"

module Pug
  class EvmLogTest < ActiveSupport::TestCase
    # test "the truth" do
    #   assert true
    # end
  end
end
