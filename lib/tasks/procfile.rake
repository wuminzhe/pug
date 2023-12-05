task default: :pug

desc 'Explaining what the task does'
task :pug do
  puts "I'm a dog!"
end

namespace :pug do
  desc 'Generate or update Procfile.pug'
  task procfile: :environment do
    File.open('Procfile.pug', 'w') do |f|
      Pug.active_networks.each do |network|
        f.puts "#{network.name}: bin/rails \"pug:track_logs[#{network.chain_id}]\""
      end
    end
    puts 'created Procfile.pug'

    # copy ./bin/pug to host app if not exists.
    pug_cli = File.expand_path('../../bin/pug', __dir__)
    dest = Rails.root.join('bin', 'pug')
    unless File.exist?(dest)
      FileUtils.cp(pug_cli, dest)
      FileUtils.chmod('+x', dest)
      puts "created #{dest}"
    end
  end
end
