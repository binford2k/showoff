require File.expand_path "../test_helper", __FILE__

context "ShowOff Utils tests" do
  setup do
  end

  #  create, init - Create new showoff presentation
  test "can initialize a new preso" do
    files = []
    in_temp_dir do
      ShowOffUtils.create('testing', true)
      files = Dir.glob('testing/**/*')
    end
    assert_equal %w(testing/one testing/one/01_slide.md testing/showoff.json), files.sort
  end

  #  heroku       - Setup your presentation to serve on Heroku
  test "can herokuize" do
    files = []
    in_basic_dir do
      ShowOffUtils.heroku('test')
      files = Dir.glob('**/*')
      content = File.read('Gemfile')
      assert_match 'showoff', content
      assert_match 'heroku', content
    end
    assert files.include?('config.ru')
    assert files.include?('Gemfile')
  end

  test "can herokuize with password" do
    in_basic_dir do
      ShowOffUtils.heroku('test', false, 'pwpw')
      content = File.read('config.ru')
      assert_match 'Rack::Auth::Basic', content
      assert_match 'pwpw', content
    end
  end

  #  static       - Generate static version of presentation
  test "can create a static version" do
    in_image_dir do
      ShowOff.do_static(nil)
      content = File.read('static/index.html')
      assert_match 'My Presentation', content
      assert_equal 2, content.scan(/div class="slide"/).size
      assert_match 'img src="./file/one/chacon.jpg" alt="chacon"', content
    end
  end

  #  github       - Puts your showoff presentation into a gh-pages branch
  test "can create a github version" do
    in_image_dir do
      ShowOffUtils.github
      files = `git ls-tree gh-pages`.chomp.split("\n")
      assert_equal 4, files.size
      content = `git cat-file -p gh-pages:index.html`
      assert_match 'My Presentation', content
      assert_equal 2, content.scan(/div class="slide"/).size
      assert_match 'img src="./file/one/chacon.jpg" alt="chacon"', content
    end
  end

  test 'should obtain value for pause_msg setting' do
    dir = File.join(File.dirname(__FILE__), 'fixtures', 'simple')
    msg = ShowOffUtils.pause_msg(dir)

    assert_match 'Test_paused', msg
  end

  test 'should obtain default value for pause_msg setting' do
    msg = ShowOffUtils.pause_msg

    assert_match 'PAUSED', msg
  end

  test 'can obtain value for default style setting' do
    dir = File.join(File.dirname(__FILE__), 'fixtures', 'style')
    style = ShowOffUtils.default_style(dir)

    assert_equal 'some_thing', style
  end

  test 'should have default value for default style setting' do
    style = ShowOffUtils.default_style

    assert_equal '', style
  end

  test 'can indicate a style choice matching the default' do
    dir = File.join(File.dirname(__FILE__), 'fixtures', 'style')

    assert ShowOffUtils.default_style?('some_thing', dir)
  end

  test 'can indicate a style choice not matching the default' do
    dir = File.join(File.dirname(__FILE__), 'fixtures', 'style')

    assert !ShowOffUtils.default_style?('something_else', dir)
  end

  test 'can indicate a style choice matching the default after stripping away extra path information and extension' do
    dir = File.join(File.dirname(__FILE__), 'fixtures', 'style')

    assert ShowOffUtils.default_style?('some/long/path/to/some_thing.css', dir)
  end
end
