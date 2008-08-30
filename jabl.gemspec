require 'rubygems'
require 'rake'

def readmes(path = '.')
  FileList.new(File.join(path, '*')) do |list|
    list.exclude(/(^|[^.a-z])[a-z]+/)
  end.to_a
end

version = File.read('VERSION').strip

JABL_GEMSPEC = Gem::Specification.new do |spec|
  spec.rubyforge_project = spec.name = 'jabl'
  spec.summary = "An indentation-based alternate syntax for Javascript."
  spec.version = version
  spec.authors = ['Nathan Weizenbaum']
  spec.email = 'nex342@gmail.com'
  spec.files = FileList['{lib,test}/**/*', 'Rakefile', 'vendor/jabl-rkelly/{Rakefile,{lib,test}/**/*}'].to_a +
    readmes + readmes('vendor/jabl-rkelly')
end
