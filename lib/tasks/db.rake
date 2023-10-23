namespace :db do
  desc 'reset db'
  task dp: ['db:drop', 'db:create', 'db:migrate', 'db:seed']
end
