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
module Pug
  class Network < ApplicationRecord
    has_many :evm_contracts

    def client
      Api::RpcClient.new(rpc_list.first)
    end
  end
end
