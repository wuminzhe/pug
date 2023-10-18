# == Schema Information
#
# Table name: pug_networks
#
#  id           :integer          not null, primary key
#  chain_id     :integer
#  name         :string
#  display_name :string
#  rpc_list     :json
#  scan_span    :integer
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
require "test_helper"

module Pug
  class NetworkTest < ActiveSupport::TestCase
    # test "the truth" do
    #   assert true
    # end
  end
end
