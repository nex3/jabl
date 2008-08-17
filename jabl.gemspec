require 'rubygems'
require 'rake'

version = File.read('VERSION').strip

JABL_GEMSPEC = Gem::Specification.new do |spec|
  spec.rubyforge_project = spec.name = 'jabl'
  spec.summary = "An indentation-based alternate syntax for Javascript."
  spec.version = version
  spec.authors = ['Nathan Weizenbaum']
  spec.email = 'nex342@gmail.com'
  spec.add_dependency 'jabl-rkelly', "= #{version}"
  readmes = FileList.new('*') do |list|
    list.exclude(/(^|[^.a-z])[a-z]+/)
  end.to_a
  spec.files = FileList['lib/**/*', 'test/**/*', 'Rakefile'].to_a + readmes
end
