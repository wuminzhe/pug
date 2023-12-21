namespace :pug do
  desc 'Generate event models'
  task generate_event_models: :environment do
    Pug::EvmContract.all.each do |contract|
      Pug.generate_models(contract)
    end
  end
end
