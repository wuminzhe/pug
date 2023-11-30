require_relative 'lib/pug/version'

Gem::Specification.new do |spec|
  spec.name = 'pug'
  spec.version     = Pug::VERSION
  spec.authors     = ['Aki Wu']
  spec.email       = ['wuminzhe@gmail.com']
  spec.homepage    = 'https://github.com/wuminzhe/pug'
  spec.summary     = 'mini evm events indexer gem'
  spec.description = 'mini evm events indexer gem'
  spec.license     = 'MIT'

  spec.metadata['homepage_uri'] = spec.homepage

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir['{app,config,db,lib}/**/*', 'MIT-LICENSE', 'Rakefile', 'README.md']
  end

  spec.add_dependency 'abi_coder_rb', '~> 0.2.2'
  spec.add_dependency 'rails', '>= 7.1.1'
end
