require 'rubygems'
require 'rake'

require 'rake/gempackagetask'
load    'jabl.gemspec'

Rake::GemPackageTask.new(JABL_GEMSPEC) do |pkg|
  pkg.need_tar_gz = Rake.application.top_level_tasks.include?('release')
end

desc "Install Jabl as a gem."
task :install => [:package] do
  sudo = RUBY_PLATFORM =~ /win32/ ? '' : 'sudo'
  sh %{#{sudo} gem install pkg/jabl-#{File.read('VERSION').strip}}
end

desc "Release a new Jabl package to Rubyforge. Requires the NAME and VERSION flags."
task :release => [:package] do
  name, version = ENV['NAME'], ENV['VERSION']
  raise "Must supply NAME and VERSION for release task." unless name && version
  sh %{rubyforge login}
  sh %{rubyforge add_release jabl jabl "#{name} (v#{version})" pkg/jabl-#{version}.gem}
  sh %{rubyforge add_file    jabl jabl "#{name} (v#{version})" pkg/jabl-#{version}.tar.gz}
end
