RSpec.describe Showoff::Compiler::Notes do
  before(:each) do
    Showoff::Config.load(File.join(fixtures, 'notes', 'showoff.json'))
  end

  it 'handles slides with no notes sections' do
    options = {:form=>nil, :name=>"standalone", :seq=>nil}
    content = <<-EOF
<h1>This slide has no notes</h1>

<p>Just some boring content.</p>
EOF

    doc = Nokogiri::HTML::DocumentFragment.parse(content)
    doc, notes = Showoff::Compiler::Notes.render!(doc, {}, options)

    expect(doc.element_children.size).to eq(2)
    expect(doc.element_children[0].name).to eq('h1')
    expect(doc.element_children[1].name).to eq('p')
    expect(notes.empty?).to be_truthy
  end

  it 'creates notes and handout sections' do
    options = {:form=>nil, :name=>"content", :seq=>1}
    content = <<-EOF
<h1>Notes and handouts both</h1>

<p>blah blah blah</p>

<p>~~~SECTION:notes~~~</p>

<p>These are some notes, yo</p>

<p>~~~ENDSECTION~~~</p>

<p>~~~SECTION:handouts~~~</p>

<p>And some handouts, yeah</p>

<p>~~~ENDSECTION~~~</p>
EOF

    doc = Nokogiri::HTML::DocumentFragment.parse(content)
    doc, notes = Showoff::Compiler::Notes.render!(doc, {}, options)

    expect(doc.element_children.size).to eq(2)
    expect(doc.element_children[0].name).to eq('h1')
    expect(doc.element_children[1].name).to eq('p')
    expect(notes.size).to eq(2)
    expect(notes.search('.notes-section.notes').size).to eq(1)
    expect(notes.search('.notes-section.notes .personal p').text).to start_with('(nonum)')

    expect(notes.search('.notes-section.handouts').size).to eq(1)
    expect(notes.search('.notes-section.handouts .personal').empty?).to be_truthy
  end

  it 'creates arbitrarily named sections' do
    options = {:form=>nil, :name=>"content", :seq=>2}
    content = <<-EOF
<h1>Arbitrary</h1>

<p>This slide validates that arbitrarily named sections work.</p>

<p>~~~SECTION:notes~~~</p>

<p>These are some notes, yo</p>

<p>~~~ENDSECTION~~~</p>

<p>~~~SECTION:arbitrary~~~</p>

<p>And some arbitrarily named section</p>

<p>~~~ENDSECTION~~~</p>
EOF

    doc = Nokogiri::HTML::DocumentFragment.parse(content)
    doc, notes = Showoff::Compiler::Notes.render!(doc, {}, options)

    expect(doc.element_children.size).to eq(2)
    expect(doc.element_children[0].name).to eq('h1')
    expect(doc.element_children[1].name).to eq('p')
    expect(notes.size).to eq(2)
    expect(notes.search('.notes-section.notes').size).to eq(1)
    expect(notes.search('.notes-section.notes .personal p').text).to start_with('(nonum)')

    expect(notes.search('.notes-section.arbitrary').size).to eq(1)
    expect(notes.search('.notes-section.arbitrary .personal').empty?).to be_truthy
  end

  it 'generates personal notes with presenter notes' do
    options = {:form=>nil, :name=>"content", :seq=>3}
    content = <<-EOF
<h1>Notes and personal</h1>

<p>This has personal notes and presenter notes.
This is a multi slide file.</p>

<p>~~~SECTION:notes~~~</p>

<p>notes and stuff</p>

<p>~~~ENDSECTION~~~</p>
EOF

    doc = Nokogiri::HTML::DocumentFragment.parse(content)
    doc, notes = Showoff::Compiler::Notes.render!(doc, {}, options)

    expect(doc.element_children.size).to eq(2)
    expect(doc.element_children[0].name).to eq('h1')
    expect(doc.element_children[1].name).to eq('p')
    expect(notes.size).to eq(1)
    expect(notes.search('.notes-section.notes').size).to eq(1)
    expect(notes.search('.notes-section.notes .personal p').text).to start_with('(3)')
  end

  it 'generates personal notes without specificed presenter notes' do
    options = {:form=>nil, :name=>"content", :seq=>4}
    content = <<-EOF
<h1>Notes and personal</h1>

<p>This has personal notes only.
This is a multi slide file.</p>
EOF

    doc = Nokogiri::HTML::DocumentFragment.parse(content)
    doc, notes = Showoff::Compiler::Notes.render!(doc, {}, options)

    expect(doc.element_children.size).to eq(2)
    expect(doc.element_children[0].name).to eq('h1')
    expect(doc.element_children[1].name).to eq('p')
    expect(notes.size).to eq(1)
    expect(notes.search('.notes-section.notes').size).to eq(1)
    expect(notes.search('.notes-section.notes .personal p').text).to start_with('(4)')
  end

  it 'generates personal notes for multi-slides when the notes are not numbered' do
    options = {:form=>nil, :name=>"content", :seq=>5}
    content = <<-EOF
<h1>Non numbered personal</h1>

<p>This has personal notes only.
This is a multi slide file, but the personal notes file is not numbered.</p>
EOF

    doc = Nokogiri::HTML::DocumentFragment.parse(content)
    doc, notes = Showoff::Compiler::Notes.render!(doc, {}, options)

    expect(doc.element_children.size).to eq(2)
    expect(doc.element_children[0].name).to eq('h1')
    expect(doc.element_children[1].name).to eq('p')
    expect(notes.size).to eq(1)
    expect(notes.search('.notes-section.notes').size).to eq(1)
    expect(notes.search('.notes-section.notes .personal p').text).to start_with('(nonum)')
  end

  it 'attaches non-numbered personal notes to all slides in a multi-slide file' do
    options = {:form=>nil, :name=>"content", :seq=>6}
    content = <<-EOF
<h1>Second non numbered personal</h1>

<p>This a second non-numbered personal notes slide. The non-numbered content
should be attached to both.</p>
EOF

    doc = Nokogiri::HTML::DocumentFragment.parse(content)
    doc, notes = Showoff::Compiler::Notes.render!(doc, {}, options)

    expect(doc.element_children.size).to eq(2)
    expect(doc.element_children[0].name).to eq('h1')
    expect(doc.element_children[1].name).to eq('p')
    expect(notes.size).to eq(1)
    expect(notes.search('.notes-section.notes').size).to eq(1)
    expect(notes.search('.notes-section.notes .personal p').text).to start_with('(nonum)')
  end

  it 'generates personal notes for numbered slides in a single slide file' do
    options = {:form=>nil, :name=>"separate", :seq=>nil}
    content = <<-EOF
<h1>Notes and personal</h1>

<p>This has personal notes attached to a separate file.</p>
EOF

    doc = Nokogiri::HTML::DocumentFragment.parse(content)
    doc, notes = Showoff::Compiler::Notes.render!(doc, {}, options)

    expect(doc.element_children.size).to eq(2)
    expect(doc.element_children[0].name).to eq('h1')
    expect(doc.element_children[1].name).to eq('p')
    expect(notes.size).to eq(1)
    expect(notes.search('.notes-section.notes').size).to eq(1)
    expect(notes.search('.notes-section.notes .personal p').text).to start_with('(separate)')
  end

end



