namespace :db do
  desc 'drop, then prepare'
  task dp: ['db:drop', 'db:create', 'db:migrate']
end
