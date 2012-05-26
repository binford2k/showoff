require File.expand_path "../test_helper", __FILE__

context "ShowOff Special Content tests" do
  def app
    opt = {:verbose => false, :pres_dir => 'test/fixtures/special_content', :pres_file => 'showoff.json'}
    ShowOff.set opt
    ShowOff.new
  end

  def get_slide(i)
    get '/slides'
    html = Nokogiri::HTML.parse(last_response.body)
    html.css('div.slide')[i-1]
  end

  test 'converts `.notes` lines to notes-class paragraphs' do
    slide = get_slide(1)
    assert_equal 'Some notes for the first slide', slide.css('p.notes').text
  end

  test 'handles notes lines placed before slide content' do
    slide = get_slide(2)
    assert_equal 'Some more notes, longer and more interesting I guess', slide.css('p.notes').text
  end

  test 'handles notes split across lines' do
    slide = get_slide(3)
    assert_equal "Sometimes notes can go on and on and on and on and on\nand on and on, much longer than you need them to.", slide.css('p.notes').text
  end
  
  test 'handles multi-line notes with the special-content marker repeated' do
    slide = get_slide(4)
    assert_equal "Sometimes notes really do go on so long\nyou just have no idea what to do with them\nand you don't want to keep on saying .notes\nbut you can't find a way to make yourself stop.", slide.css('p.notes').text
  end

  test 'handles slides without notes' do
    slide = get_slide(5)
    assert_equal 0, slide.css('p.notes').length
  end

  test 'handles slides with empty notes' do
    slide = get_slide(6)
    assert_equal '', slide.css('p.notes').text
  end
  
  test 'handles multi-line notes with the special-content marker repeated' do
    slide = get_slide(7)
    assert_equal "Sometimes notes have something interesting to say.\n\nAnd you just want to pause and think about it.\n\n  And think about it some more.", slide.css('p.notes').text
  end
end
