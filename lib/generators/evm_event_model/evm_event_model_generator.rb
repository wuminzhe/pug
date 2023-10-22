require 'rails/generators'
require 'rails/generators/active_record/model/model_generator'

class EvmEventModelGenerator < ActiveRecord::Generators::ModelGenerator
  source_root File.expand_path('templates', __dir__)
  Rails::Generators.templates_path.each do |path|
    source_paths << File.join(path, base_name, 'migration')
  end
  source_paths << File.expand_path(File.join(base_name, 'migration', 'templates'), base_root)

  def create_migration_file
    if options[:indexes] == false
      attributes.each do |a|
        a.attr_options.delete(:index) if a.reference? && !a.has_index?
      end
    end
    migration_template 'create_table_migration.rb', File.join(db_migrate_path, "create_#{table_name}.rb")
  end

  def create_model_file
    template 'model.rb', File.join('app/models', class_path, "#{file_name}.rb")
  end
end
