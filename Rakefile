task default: :test

desc "Build HTML documentation"
task :doc do
  system("rdoc --main README.rdoc README.rdoc documentation/*.rdoc")
end

desc "Run tests"
task :test do
  require 'rake/testtask'

  Rake::TestTask.new do |t|
    t.libs << 'lib'
    t.pattern = 'test/**/*_test.rb'
    t.verbose = false
  end

  suffix = "-n #{ENV['TEST']}" if ENV['TEST']
  sh "turn test/*_test.rb #{suffix}"
end

begin
  require 'mg'
  MG.new("showoff.gemspec")
rescue LoadError
  puts "'gem install mg' to get helper gem publishing tasks. (optional)"
end

