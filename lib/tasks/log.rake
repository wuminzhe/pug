namespace :pug do
  desc 'Track logs of a chain'
  task :track_logs, %i[chain_id] => :environment do |_t, args|
    $stdout.sync = true

    network = Pug::Network.find_by(chain_id: args[:chain_id])
    raise "Network with chain_id #{args[:chain_id]} not found" if network.nil?

    loop do
      ActiveRecord::Base.transaction do
        Pug.scan_logs_of_network(network) do |logs|
          logs.each do |log|
            Pug::EvmLog.create_from(network, log)
          end
        end
      end
    rescue StandardError => e
      puts e.message
      puts e.backtrace.join("\n")
    ensure
      sleep 5
    end
  end
end
