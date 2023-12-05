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
module Pug
  class Network < ApplicationRecord
    has_many :evm_contracts

    def client
      raise 'rpc is empty' if rpc.blank?

      JsonRpcClient.new(rpc)
    end
  end
end
