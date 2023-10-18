# == Schema Information
#
# Table name: pug_evm_contracts
#
#  id               :integer          not null, primary key
#  network_id       :integer          not null
#  address          :string
#  abi_file         :string
#  creator          :string
#  creation_block   :integer
#  creation_tx_hash :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
require "test_helper"

module Pug
  class EvmContractTest < ActiveSupport::TestCase
    # test "the truth" do
    #   assert true
    # end
  end
end
