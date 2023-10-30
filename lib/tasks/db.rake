namespace :db do
  desc 'Rebuild database'
  task rebuild: [:environment, 'db:drop', 'db:create', 'db:migrate', 'db:seed']
end
