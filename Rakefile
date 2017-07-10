require 'fileutils'

task :default do
  system("rake -T")
end

def version
  `git describe --tags  --abbrev=0`.chomp.sub('v','')
end

def next_version(type = :patch)
  section = [:major,:minor,:patch].index type

  n = version.split '.'
  n[section] = n[section].to_i + 1
  n.join '.'
end

def translate(text, lang)
  require 'net/http'
  require 'uri'
  require 'json'

  uri    = URI.parse("https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=#{lang}&dt=t&q=#{URI.escape(text)}")
  result = Net::HTTP.get_response(uri)
  data   = JSON.parse(result.body);

  data.first.map { |sentence| sentence.first }.join
end

desc "Build Docker image"
task 'docker' do
  Dir.chdir('build') do
    system("docker build --no-cache=true -t binford2k/showoff:#{version} -t binford2k/showoff:latest .")
  end
  puts
  puts 'Start container with: docker run -p 9090:9090 binford2k/showoff'
end

desc "Upload image to Docker Hub"
task 'docker:push' => ['docker'] do
  system("docker push binford2k/showoff:#{version}")
  system("docker push binford2k/showoff:latest")
end

desc "Build HTML documentation"
task :doc do
  FileUtils.rm_rf('doc')
  Dir.chdir('documentation') do
    system("rdoc --main -HOME.rdoc /*.rdoc --op ../doc")
  end
end

desc "Update docs for webpage"
task 'doc:website' => [:doc] do
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


desc 'Validate translation files'
task 'lang:check' do
  require 'yaml'

  def compare_keys(left, right, code, name, stack=nil)
    left.each do |key, val|
      inner   = stack.nil? ? key : "#{stack}.#{key}"
      compare = right[key]

      case compare
      when Hash
        compare_keys(val, compare, code, name, inner)
      when String
        next
      when NilClass
        puts "Error: '#{inner}' is missing from #{name}"
        puts " ↳ maybe: #{translate(val, code)}" if val.is_a? String
      else
        puts "Error: '#{inner}' in #{name} is a #{compare.class}, not a Hash"
      end
    end

  end

  canonical = YAML.load_file('locales/en.yml')
  languages = Dir.glob('locales/*.yml').reject {|lang| lang == 'locales/en.yml' }

  languages.each do |langfile|
    lang = YAML.load_file(langfile)
    code = File.basename(langfile, '.yml')
    key  = lang.keys.first

    puts "Error: #{langfile} has the wrong language code (#{key})" unless code == key
    compare_keys(canonical['en'], lang[key], code, langfile)
  end
end

begin
  require 'mg'
  MG.new("showoff.gemspec")
rescue LoadError
  puts "'gem install mg' to get helper gem publishing tasks. (optional)"
end

