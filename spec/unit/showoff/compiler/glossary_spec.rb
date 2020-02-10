RSpec.describe Showoff::Compiler::Glossary do
  content = <<-EOF
<h1>This is a simple HTML slide with glossary entries</h1>
<p>This will have <a href="glossary://term-with-no-spaces" title="The definition of the term.">a phrase</a> in the paragraph.</p>
<p class="callout glossary">By hand, yo!|by-hand: I made this one by hand.</p>
<p>This <a href="glossary://name/term-with-no-spaces" title="The definition of the term.">entry</a> is attached to a named glossary.</p>
<p class="callout glossary name">By hand, yo!|by-hand: I made this one by hand.</p>
EOF

  it "generates glossary entries on a slide" do
    doc = Nokogiri::HTML::DocumentFragment.parse(content)

    # This call mutates the passed in object
    Showoff::Compiler::Glossary.render!(doc)

    callouts = doc.search('.callout.glossary').select {|n| n.ancestors.size == 1}
    links    = doc.search('a').select {|n| n.ancestors.size == 2}

    expect(doc).to be_a(Nokogiri::HTML::DocumentFragment)
    expect(doc.search('.callout.glossary').length).to eq(6)
    expect(callouts.length).to eq(2)
    expect(callouts.first.classes).to eq(["callout", "glossary"])
    expect(callouts.first.element_children.size).to eq(1)
    expect(callouts.first.element_children.first[:href]).to eq('glossary://by-hand')

    expect(callouts.last.classes).to eq(["callout", "glossary", "name"])
    expect(callouts.last.element_children.size).to eq(1)
    expect(callouts.last.element_children.first[:href]).to eq('glossary://name/by-hand')

    expect(links.length).to eq(4)
    expect(links.select {|link| link[:href].start_with? 'glossary://'}.size).to eq(4)
    expect(links.select {|link| link.classes.include? 'term'}.size).to eq(2)
    expect(links.select {|link| link.classes.include? 'label'}.size).to eq(2)
  end

  it "generates glossary entries in the presenter notes section of a slide" do
    doc = Nokogiri::HTML::DocumentFragment.parse(content)

    # This call mutates the passed in object
    Showoff::Compiler::Glossary.render!(doc)

    expect(doc).to be_a(Nokogiri::HTML::DocumentFragment)
    expect(doc.search('.notes-section.notes').length).to eq(1)
    expect(doc.search('.notes-section.notes > .callout.glossary').length).to eq(2)
    expect(doc.search('.notes-section.handouts > .callout.glossary').length).to eq(2)
  end

  it "generates glossary entries in the handout notes section of a slide" do
    doc = Nokogiri::HTML::DocumentFragment.parse(content)

    # This call mutates the passed in object
    Showoff::Compiler::Glossary.render!(doc)

    expect(doc).to be_a(Nokogiri::HTML::DocumentFragment)
    expect(doc.search('.notes-section.handouts').length).to eq(1)
    expect(doc.search('.notes-section.handouts > .callout.glossary').length).to eq(2)
  end

  it "generates a glossary page" do
    html = File.read(File.join(fixtures, 'glossary_toc', 'content.html'))
    doc  = Nokogiri::HTML::DocumentFragment.parse(html)

    Showoff::Compiler::Glossary.generatePage!(doc)

    expect(doc.search('.slide.glossary:not(.name)').size).to eq(1)
    expect(doc.search('.slide.glossary:not(.name) li a').size).to eq(4)
    expect(doc.search('.slide.glossary:not(.name) li a')[0][:id]).to eq('content:3+by-hand')
    expect(doc.search('.slide.glossary:not(.name) li a')[1][:href]).to eq('#content:2')
    expect(doc.search('.slide.glossary:not(.name) li a')[2][:id]).to eq('content:3+term-with-no-spaces')
    expect(doc.search('.slide.glossary:not(.name) li a')[3][:href]).to eq('#content:2')

    expect(doc.search('.slide.glossary.name').size).to eq(1)
    expect(doc.search('.slide.glossary.name li a').size).to eq(4)
    expect(doc.search('.slide.glossary.name li a')[0][:id]).to eq('content:4+by-hand')
    expect(doc.search('.slide.glossary.name li a')[1][:href]).to eq('#content:2')
    expect(doc.search('.slide.glossary.name li a')[2][:id]).to eq('content:4+term-with-no-spaces')
    expect(doc.search('.slide.glossary.name li a')[3][:href]).to eq('#content:2')
  end

end
