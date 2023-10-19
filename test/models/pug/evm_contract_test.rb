# == Schema Information
#
# Table name: pug_evm_contracts
#
#  id                 :integer          not null, primary key
#  network_id         :integer
#  address            :string
#  abi_file           :string
#  creator            :string
#  creation_block     :integer
#  creation_tx_hash   :string
#  creation_timestamp :datetime
#  last_scanned_block :integer
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
require "test_helper"

module Pug
  class EvmContractTest < ActiveSupport::TestCase
    # test "the truth" do
    #   assert true
    # end
  end
end
