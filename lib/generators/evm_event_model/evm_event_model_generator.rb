require 'rails/generators'
require 'rails/generators/active_record/model/model_generator'

class EvmEventModelGenerator < ActiveRecord::Generators::ModelGenerator
  source_root File.expand_path('templates', __dir__)

  def create_model_file
    template 'model.rb', File.join('app/models', class_path, "#{file_name}.rb")
  end
end
