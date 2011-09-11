require 'rake/testtask'

begin
  require 'mg'
rescue LoadError
  abort "Please `gem install mg`"
end

MG.new("showoff.gemspec")

#
# Tests
#

task :default => :test

desc "Run tests"
task :turn do
  suffix = "-n #{ENV['TEST']}" if ENV['TEST']
  sh "turn test/*_test.rb #{suffix}"
end

Rake::TestTask.new do |t|
  t.libs << 'lib'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = false
end
