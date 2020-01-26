RSpec.describe Showoff::Compiler::Fixups do

  it "replaces paragraph classes" do
    content = <<-EOF
<h1>This is a simple HTML slide</h1>
<p>.this.is.a.test This paragraph should have several classes applied.</p>
<p>.singular This should only have one.</p>
<p>And this has none.</p>
EOF
    doc = Nokogiri::HTML::DocumentFragment.parse(content)

    # This call mutates the passed in object
    Showoff::Compiler::Fixups.updateClasses!(doc)
    elements = doc.search('p')

    expect(doc).to be_a(Nokogiri::HTML::DocumentFragment)
    expect(elements.length).to eq(3)
    expect(elements[0].classes).to eq(['this', 'is', 'a', 'test'])
    expect(elements[1].classes).to eq(['singular'])
    expect(elements[2].classes).to eq([])
  end

  it "removes comments and breaks" do
    content = <<-EOF
<h1>This is a simple HTML slide</h1>
<p>.this.is.a.test This paragraph should have several classes applied.</p>
<p>.comment This should be removed.</p>
<p>.break so should this.</p>
<p>And this has none.</p>
EOF
    doc = Nokogiri::HTML::DocumentFragment.parse(content)

    # This call mutates the passed in object
    Showoff::Compiler::Fixups.updateClasses!(doc)
    elements = doc.search('p')

    expect(doc).to be_a(Nokogiri::HTML::DocumentFragment)
    expect(elements.length).to eq(2)
    expect(elements[0].classes).to eq(['this', 'is', 'a', 'test'])
    expect(elements[1].classes).to eq([])
  end

  it "replaces image classes" do
    content = <<-EOF
<h1>This is a simple HTML slide</h1>
<p><img src="path/to/img.jpg" alt=".this.is.a.test" /></p>
EOF
    doc = Nokogiri::HTML::DocumentFragment.parse(content)

    # This call mutates the passed in object
    Showoff::Compiler::Fixups.updateClasses!(doc)
    paragraphs = doc.search('p')
    images     = doc.search('img')

    expect(doc).to be_a(Nokogiri::HTML::DocumentFragment)
    expect(paragraphs.length).to eq(1)
    expect(paragraphs.text).to eq('')
    expect(images.length).to eq(1)
    expect(images[0].classes).to eq(['this', 'is', 'a', 'test'])
  end

  it "updates link targets" do
    content = <<-EOF
<h1>This is a simple HTML slide</h1>
<ul>
<li><a href="http://google.com">a link</a></li>
<li><a href="#in-page-anchor">a second</a></li>
<li><a href="glossary://foo-bar">a third</a></li>
<li><a id="in-page-anchor">no href!</a></li>
</ul>
EOF
    doc = Nokogiri::HTML::DocumentFragment.parse(content)

    # This call mutates the passed in object
    Showoff::Compiler::Fixups.updateLinks!(doc)
    paragraphs = doc.search('p')
    anchors    = doc.search('a')

    expect(doc).to be_a(Nokogiri::HTML::DocumentFragment)
    expect(paragraphs.length).to eq(0)
    expect(anchors.length).to eq(4)
    expect(anchors[0].attribute('target').value).to eq('_blank')
    expect(anchors[1].attribute('target')).to be_nil
    expect(anchors[2].attribute('target')).to be_nil
    expect(anchors[3].attribute('target')).to be_nil
  end

  it "correctly munges backtick fenced code blocks" do
    content = <<-EOF
<h1>This is a simple HTML slide with code</h1>
<pre><code>echo 'hello'
</code></pre>
<pre><code class="language-ruby">puts 'hello'
</code></pre>
<pre><code class="language-ruby:goodbye">puts 'goodbye'
</code></pre>
EOF
    doc = Nokogiri::HTML::DocumentFragment.parse(content)

    # This call mutates the passed in object
    Showoff::Compiler::Fixups.updateSyntaxHighlighting!(doc)
    paragraphs = doc.search('p')
    pre        = doc.search('pre')
    code       = doc.search('code')

    expect(doc).to be_a(Nokogiri::HTML::DocumentFragment)
    expect(paragraphs.length).to eq(0)
    expect(pre.length).to eq(3)
    expect(code.length).to eq(3)
    expect(pre[0].classes).to eq([])
    expect(pre[1].classes).to eq(['highlight'])
    expect(pre[2].classes).to eq(['highlight'])
    expect(code[0].classes).to eq([])
    expect(code[1].classes).to eq(['language-ruby'])
    expect(code[2].classes).to eq(['language-ruby', 'goodbye'])
  end

  it "correctly munges showoff syntax tags" do
    content = <<-EOF
<h1>This is a simple HTML slide with showoff syntax tags</h1>
<pre><code>
echo 'hello'
</code></pre>
<pre><code>@@@ ruby
puts 'hello'
</code></pre>
<pre><code>@@@ ruby goodbye
puts 'goodbye'
</code></pre>
EOF
    doc = Nokogiri::HTML::DocumentFragment.parse(content)

    # This call mutates the passed in object
    Showoff::Compiler::Fixups.updateSyntaxHighlighting!(doc)
    paragraphs = doc.search('p')
    pre        = doc.search('pre')
    code       = doc.search('code')

    expect(doc).to be_a(Nokogiri::HTML::DocumentFragment)
    expect(paragraphs.length).to eq(0)
    expect(pre.length).to eq(3)
    expect(code.length).to eq(3)
    expect(pre[0].classes).to eq([])
    expect(pre[1].classes).to eq(['highlight'])
    expect(pre[2].classes).to eq(['highlight'])
    expect(code[0].classes).to eq([])
    expect(code[1].classes).to eq(['language-ruby'])
    expect(code[2].classes).to eq(['language-ruby', 'goodbye'])
  end

  context "image path cleanup" do
    it "cleans up image paths for slide in presentation root" do
      content = <<-EOF
<h1>This is a simple HTML slide with image tags</h1>
<p><img src="_images/hackerrrr.jpg" alt="Hackerrrr"></p>
<p><img src="/_images/another.jpg" alt="Another silly picture"></p>
EOF
      doc = Nokogiri::HTML::DocumentFragment.parse(content)

      # This call mutates the passed in object
      Showoff::Compiler::Fixups.updateImagePaths!(doc, {:name => 'foo.md'})
      imgs = doc.search('img')

      expect(doc).to be_a(Nokogiri::HTML::DocumentFragment)
      expect(imgs.length).to eq(2)
      expect(imgs[0][:src]).to eq('_images/hackerrrr.jpg')
      expect(imgs[1][:src]).to eq('/_images/another.jpg')
    end

    it "cleans up image paths for slide in directory" do
      content = <<-EOF
<h1>This is a simple HTML slide with image tags</h1>
<p><img src="../_images/hackerrrr.jpg" alt="Hackerrrr"></p>
<p><img src="/_images/another.jpg" alt="Another silly picture"></p>
EOF
      doc = Nokogiri::HTML::DocumentFragment.parse(content)

      # This call mutates the passed in object
      Showoff::Compiler::Fixups.updateImagePaths!(doc, {:name => 'testing/foo.md'})
      imgs = doc.search('img')

      expect(doc).to be_a(Nokogiri::HTML::DocumentFragment)
      expect(imgs.length).to eq(2)
      expect(imgs[0][:src]).to eq('_images/hackerrrr.jpg')
      expect(imgs[1][:src]).to eq('/_images/another.jpg')
    end

    it "cleans up image paths for slide in deeply nested directory" do
      content = <<-EOF
<h1>This is a simple HTML slide with image tags</h1>
<p><img src="../../../_images/hackerrrr.jpg" alt="Hackerrrr"></p>
<p><img src="/_images/another.jpg" alt="Another silly picture"></p>
EOF
      doc = Nokogiri::HTML::DocumentFragment.parse(content)

      # This call mutates the passed in object
      Showoff::Compiler::Fixups.updateImagePaths!(doc, {:name => 'foo/bar/baz/testing.md'})
      imgs = doc.search('img')

      expect(doc).to be_a(Nokogiri::HTML::DocumentFragment)
      expect(imgs.length).to eq(2)
      expect(imgs[0][:src]).to eq('_images/hackerrrr.jpg')
      expect(imgs[1][:src]).to eq('/_images/another.jpg')
    end
  end

  # I don't actually know precisely what this routine does yet.....
  it "correctly munges commandline blocks"

end



