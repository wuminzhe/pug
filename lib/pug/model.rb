module Pug
  def self.generate_models(evm_contract)
    evm_contract.event_signatures.each do |event_signature|
      generate_model(evm_contract, event_signature)
    end
  end

  def self.generate_model(contract, event_signature)
    # model name
    model_name = contract.event_full_name(event_signature)

    # columns
    columns = contract.event_columns(event_signature)
    columns_str = columns.map { |c| "#{c[0]}:#{c[1]}:index" }.join(' ')

    if Pug.const_defined?(model_name)
      puts "Model already exists: Pug::#{model_name}"
    else
      # p "rails g evm_event_model Pug::#{model_name} pug_evm_log:belongs_to #{columns_str} --no-test-framework"
      unless Rails.root.join('app', 'models', 'pug', "#{model_name.underscore}.rb").exist?
        belongs_to_str = 'pug_evm_log:belongs_to pug_evm_contract:belongs_to pug_network:belongs_to'
        extra_columns_str = 'timestamp:datetime block_number:integer transaction_index:integer log_index:integer'
        system("./bin/rails g evm_event_model Pug::#{model_name} #{belongs_to_str} #{columns_str} #{extra_columns_str} --timestamps --no-test-framework")
      end
    end
  end
end
