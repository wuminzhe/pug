# == Schema Information
#
# Table name: pug_networks
#
#  id                 :integer          not null, primary key
#  chain_id           :bigint
#  name               :string
#  display_name       :string
#  rpc                :string
#  explorer           :string
#  scan_span          :integer          default(2000)
#  last_scanned_block :integer          default(0)
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
require "test_helper"

module Pug
  class NetworkTest < ActiveSupport::TestCase
    # test "the truth" do
    #   assert true
    # end
  end
end
