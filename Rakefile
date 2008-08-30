require 'rubygems'
require 'rake'

require 'rake/gempackagetask'
load    'jabl.gemspec'

# --- Packaging ---

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

# --- Jabl::RKelly management ---

desc "Update the jabl-rkelly submodule."
task :update_submodule do
  sh 'git submodule init'
  sh 'git submodule update'
end

desc "Build the generated Jabl::RKelly parser."
task :parser do
  Dir.chdir('vendor/jabl-rkelly')
  sh 'rake parser'
  Dir.chdir(File.dirname(__FILE__))
end

desc "Update Jabl::RKelly and build the parser."
task :update => [:update_submodule, :parser]

Rake::Task[:package].prerequisites << :update
