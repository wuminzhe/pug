namespace :db do
  desc 'initialize database'
  task init: ['db:drop', 'db:create', 'db:migrate', 'db:seed']
end
