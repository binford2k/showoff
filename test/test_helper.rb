dir = File.dirname(File.expand_path(__FILE__))
$TEST_DIR = File.dirname(File.expand_path(__FILE__))
$LOAD_PATH.unshift dir + '/../lib'
$TESTING = true
require 'test/unit'
require 'rubygems'
require 'showoff'
require 'rack/test'
require 'tempfile'
require 'pp'

class Test::Unit::TestCase
  include Rack::Test::Methods
end

##
# test/spec/mini 3
# http://gist.github.com/25455
# chris@ozmm.org
#
def context(*args, &block)
  return super unless (name = args.first) && block
  require 'test/unit'
  klass = Class.new(defined?(ActiveSupport::TestCase) ? ActiveSupport::TestCase : Test::Unit::TestCase) do
    def self.test(name, &block)
      define_method("test_#{name.gsub(/\W/,'_')}", &block) if block
    end
    def self.xtest(*args) end
    def self.setup(&block) define_method(:setup, &block) end
    def self.teardown(&block) define_method(:teardown, &block) end
  end
  (class << klass; self end).send(:define_method, :name) { name.gsub(/\W/,'_') }
  klass.class_eval &block
  ($contexts ||= []) << klass # make sure klass doesn't get GC'd
  klass
end

def in_temp_dir
  file = Tempfile.new('dir')
  dir = file.path
  file.unlink
  Dir.mkdir(dir)
  Dir.chdir(dir) do
    yield
  end
end

def in_basic_dir
  in_temp_dir do
    ShowOffUtils.create('testing', true)
    Dir.chdir 'testing' do
      ShowOff.pres_dir_current
      `git init`
      `git add .`
      `git commit -m 'init'`
      yield
    end
  end
end

def in_image_dir
  in_temp_dir do
    FileUtils.cp_r(File.join($TEST_DIR, 'fixtures/image'), '.')
    Dir.chdir 'image' do
      ShowOff.pres_dir_current
      `git init`
      `git init`
      `git add .`
      `git commit -m 'init'`
      yield
    end
  end
end
