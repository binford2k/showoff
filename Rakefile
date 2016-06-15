task :default do
  system("rake -T")
end

desc "Build HTML documentation"
task :doc do
  require 'fileutils'

  FileUtils.rm_rf('doc')
  Dir.chdir('documentation') do
    system("rdoc --main -HOME.rdoc /*.rdoc --op ../doc")
  end
end

desc "Update docs for webpage"
task 'web:doc' => [:doc] do
  require 'fileutils'

  if system('git checkout gh-pages')
    FileUtils.rm_rf('documentation')
    FileUtils.mv('doc', 'documentation')
    system('git add documentation')
    system('git commit -m "updating docs"')
    system('git checkout -')

    puts "Publish updates by pushing to Github:"
    puts
    puts "    git push upstream gh-pages"
    puts
  end
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

