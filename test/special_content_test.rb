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

  def get_notes(slide)
    slide.css('div.notes')
  end

  def get_notes_contents(slide)
    container = get_notes(slide)
    container.inner_html
  end

  def assert_html_match(expected, actual)
    assert_equal html_normalize(expected), html_normalize(actual)
  end

  def html_normalize(html)
    doc = Nokogiri::HTML::DocumentFragment.parse html
    doc.children.select(&:text?).each do |node|
      node.content = ' ' if node.text.strip.empty?
    end

    doc.to_html.strip
  end

  test 'converts `.notes` lines to formatted notes-class divs' do
    slide = get_slide(1)
    expected = '<p>Some notes for the first slide</p>'

    assert_html_match expected, get_notes_contents(slide)
  end

  test 'handles notes lines placed before slide content' do
    slide = get_slide(2)
    expected = '<p>Some more notes, longer and more interesting I guess</p>'

    assert_html_match expected, get_notes_contents(slide)
  end

  test 'handles notes split across lines' do
    slide = get_slide(3)
    expected = "<p>Sometimes notes can go on and on and on and on and on\nand on and on, much longer than you need them to.</p>"

    assert_html_match expected, get_notes_contents(slide)
  end
  
  test 'handles multi-line notes with the special-content marker repeated' do
    slide = get_slide(4)
    expected = "<p>Sometimes notes really do go on so long\nyou just have no idea what to do with them\nand you don't want to keep on saying .notes\nbut you can't find a way to make yourself stop.</p>"

    assert_html_match expected, get_notes_contents(slide)
  end

  test 'handles slides without notes' do
    slide = get_slide(5)
    assert_equal 0, get_notes(slide).length
  end

  test 'handles slides with empty notes' do
    slide = get_slide(6)
    expected = ''

    assert_equal expected, get_notes_contents(slide)
  end
  
  test 'handles multi-line notes with formatting' do
    slide = get_slide(7)
    expected = "
<p>Sometimes notes have something interesting to say.</p>
<p>And you just want to pause and think about it.</p>
<pre><code>And think about it some more.
</code></pre>
    "

    assert_html_match expected, get_notes_contents(slide)
  end

  test 'also does special-content conversion for .handouts' do
    slide = get_slide(8)
    expected = "
<p>Now here's something special for handouts:</p>
<ul>
<li>some item</li>
<li>another item</li>
</ul>
    "

    assert_html_match expected, slide.css('div.handouts').inner_html
  end

  test 'also does special-content conversion for .solguide' do
    slide = get_slide(8)
    expected = "
<p>And if you want some exercises, just follow these steps</p>
<ol>
<li>a step</li>
<li>another step</li>
<li>last step</li>
</ol>
<p>It's as simple as that.</p>
"
    assert_html_match expected, slide.css('div.solguide').inner_html
  end

  test 'does no conversion for other marks' do
    slide = get_slide(8)
    expected = "This is just some extra fun. Nothing should happen here.\n.extra Seriously, this content is not that special."

    assert_equal expected, slide.css('p.extra').inner_html
  end
end
