RSpec.describe Showoff::Compiler::Form do

  it "parses single line combo select markup" do
    content = <<-EOF
<h1>Testing combo selects</h1>
<p>smartphone = {iPhone, Pixel, Galaxy, Moto, (Other) }</p>
EOF

    doc = Nokogiri::HTML::DocumentFragment.parse(content)

    expect(doc).to be_a(Nokogiri::HTML::DocumentFragment)
    expect(Showoff::Compiler::Form).to receive(:form_element).with(
      'foo_smartphone',
      'smartphone',
      'smartphone',
      false,
      '{iPhone, Pixel, Galaxy, Moto, (Other) }',
      'smartphone = {iPhone, Pixel, Galaxy, Moto, (Other) }',
    ).and_return('')

    # This call mutates the passed in object and invokes the form rendering
    Showoff::Compiler::Form.render!(doc, :form => 'foo')
  end

  it "renders select widgets from single line markup" do
    expect(Showoff::Compiler::Form).to receive(:form_element_select).with(
      'foo_smartphone',
      'smartphone',
      ["iPhone", "Pixel", "Galaxy", "Moto", "(Other)"],
    ).and_return('')

    Showoff::Compiler::Form.form_element(
      'foo_smartphone',
      'smartphone',
      'smartphone',
      false,
      '{iPhone, Pixel, Galaxy, Moto, (Other) }',
      'smartphone = {iPhone, Pixel, Galaxy, Moto, (Other) }',
    )
  end

  it 'generates the proper HTML markup for a select widget' do
    html = Showoff::Compiler::Form.form_element_select(
      'foo_smartphone',
      'smartphone',
      ["iPhone", "Pixel", "Galaxy", "Moto", "(Other)"],
    )
    doc = Nokogiri::HTML::DocumentFragment.parse(html)

    expect(doc.children.size).to eq(1)
    expect(doc.search('option').size).to eq(6)
    expect(doc.search('option').first.text).to eq('----')
    expect(doc.search('option').reject {|o| o[:selected] }.size).to eq(5)
    expect(doc.search('option').find {|o| o[:selected] }.text).to eq('Other')
    expect(doc.search('option').map{|o| o.text }).to eq(["----", "iPhone", "Pixel", "Galaxy", "Moto", "Other"])
  end

################################################################################

  it "parses single line combo select markup with tokenized name" do
    content = <<-EOF
<h1>Testing combo selects</h1>
<p>phoneos -> Which phone OS is developed by Google? = {iOS, [Android], Other }</p>
EOF

    doc = Nokogiri::HTML::DocumentFragment.parse(content)

    expect(doc).to be_a(Nokogiri::HTML::DocumentFragment)
    expect(Showoff::Compiler::Form).to receive(:form_element).with(
      'foo_phoneos',
      'phoneos',
      'Which phone OS is developed by Google?',
      false,
      '{iOS, [Android], Other }',
      'phoneos -> Which phone OS is developed by Google? = {iOS, [Android], Other }',
    ).and_return('')

    # This call mutates the passed in object and invokes the form rendering
    Showoff::Compiler::Form.render!(doc, :form => 'foo')
  end

  it "renders select widgets from single line markup with a tokenized name" do
    expect(Showoff::Compiler::Form).to receive(:form_element_select).with(
      'foo_phoneos',
      'phoneos',
      ['iOS', '[Android]', 'Other'],
    ).and_return('')

    Showoff::Compiler::Form.form_element(
      'foo_phoneos',
      'phoneos',
      'Which phone OS is developed by Google?',
      false,
      '{iOS, [Android], Other }',
      'phoneos -> Which phone OS is developed by Google? = {iOS, [Android], Other }',
    )
  end

  it 'generates the proper HTML markup for a tokenized name select widget' do
    html = Showoff::Compiler::Form.form_element_select(
      'foo_phoneos',
      'phoneos',
      ['iOS', '[Android]', 'Other'],
    )
    doc = Nokogiri::HTML::DocumentFragment.parse(html)

    expect(doc.children.size).to eq(1)
    expect(doc.search('option').size).to eq(4)
    expect(doc.search('option').first.text).to eq('----')
    expect(doc.search('option').find {|o| o[:selected] }).to be_nil
    expect(doc.search('option.correct').size).to eq(1)
    expect(doc.search('option.correct').first.text).to eq('Android')
    expect(doc.search('option').map{|o| o.text }).to eq(["----", "iOS", "Android", "Other"])
  end

################################################################################

  it "parses multi line select markup" do
    content = <<-EOF
<h1>Testing selects</h1>
<p>phoneos -> Which phone OS is developed by Google? = {
   iOS
   [Android]
   Other
}</p>
EOF

    doc = Nokogiri::HTML::DocumentFragment.parse(content)

    expect(doc).to be_a(Nokogiri::HTML::DocumentFragment)
    expect(Showoff::Compiler::Form).to receive(:form_element).with(
      'foo_phoneos',
      'phoneos',
      'Which phone OS is developed by Google?',
      false,
      '{',
      "phoneos -> Which phone OS is developed by Google? = {\n   iOS\n   [Android]\n   Other\n}",
    ).and_return('')

    # This call mutates the passed in object and invokes the form rendering
    Showoff::Compiler::Form.render!(doc, :form => 'foo')
  end

  it "renders selects widgets from multi line markup" do
    expect(Showoff::Compiler::Form).to receive(:form_element_select_multiline).with(
      'foo_phoneos',
      'phoneos',
      "phoneos -> Which phone OS is developed by Google? = {\n   iOS\n   [Android]\n   Other\n}",
    ).and_return('')

    Showoff::Compiler::Form.form_element(
      'foo_phoneos',
      'phoneos',
      'Which phone OS is developed by Google?',
      false,
      '{',
      "phoneos -> Which phone OS is developed by Google? = {\n   iOS\n   [Android]\n   Other\n}",
    )
  end


  it 'generates the proper HTML markup for a multiline select widget' do
    html = Showoff::Compiler::Form.form_element_select_multiline(
      'foo_phoneos',
      'phoneos',
      "phoneos -> Which phone OS is developed by Google? = {\n   iOS\n   [Android]\n   Other\n}",
    )
    doc = Nokogiri::HTML::DocumentFragment.parse(html)

    expect(doc.children.size).to eq(1)
    expect(doc.search('option').size).to eq(4)
    expect(doc.search('option').first.text).to eq('----')
    expect(doc.search('option').find {|o| o[:selected] }).to be_nil
    expect(doc.search('option.correct').size).to eq(1)
    expect(doc.search('option.correct').first.text).to eq('Android')
    expect(doc.search('option').map{|o| o.text }).to eq(["----", "iOS", "Android", "Other"])
  end

  it 'generates the proper HTML markup for a multiline select widget with one selected' do
    html = Showoff::Compiler::Form.form_element_select_multiline(
      'foo_phoneos',
      'phoneos',
      "phoneos -> Which phone OS is developed by Google? = {\n   iOS\n   [Android]\n   (Other)\n}",
    )
    doc = Nokogiri::HTML::DocumentFragment.parse(html)

    expect(doc.children.size).to eq(1)
    expect(doc.search('option').size).to eq(4)
    expect(doc.search('option').first.text).to eq('----')
    expect(doc.search('option').select {|o| o[:selected] }.size).to eq(1)
    expect(doc.search('option').find {|o| o[:selected] }.text).to eq('Other')
    expect(doc.search('option.correct').size).to eq(1)
    expect(doc.search('option.correct').first.text).to eq('Android')
    expect(doc.search('option').map{|o| o.text }).to eq(["----", "iOS", "Android", "Other"])
  end

################################################################################

  it "parses multi line select tokenized markup" do
    content = <<-EOF
<h1>Testing selects</h1>
<p>cuisine -> What is your favorite cuisine? = {
   US -> American
   IT -> Italian
   FR -> French
}</p>
EOF

    doc = Nokogiri::HTML::DocumentFragment.parse(content)

    expect(doc).to be_a(Nokogiri::HTML::DocumentFragment)
    expect(Showoff::Compiler::Form).to receive(:form_element).with(
      'foo_cuisine',
      'cuisine',
      'What is your favorite cuisine?',
      false,
      '{',
      "cuisine -> What is your favorite cuisine? = {\n   US -> American\n   IT -> Italian\n   FR -> French\n}",
    ).and_return('')

    # This call mutates the passed in object and invokes the form rendering
    Showoff::Compiler::Form.render!(doc, :form => 'foo')
  end

  it "renders selects widgets from multi line tokenized markup" do
    expect(Showoff::Compiler::Form).to receive(:form_element_select_multiline).with(
      'foo_cuisine',
      'cuisine',
      "cuisine -> What is your favorite cuisine? = {\n   US -> American\n   IT -> Italian\n   FR -> French\n}",
    ).and_return('')

    Showoff::Compiler::Form.form_element(
      'foo_cuisine',
      'cuisine',
      'What is your favorite cuisine?',
      false,
      '{',
      "cuisine -> What is your favorite cuisine? = {\n   US -> American\n   IT -> Italian\n   FR -> French\n}",
    )
  end


  it 'generates the proper HTML markup for a tokenized multiline select widget' do
    html = Showoff::Compiler::Form.form_element_select_multiline(
      'foo_cuisine',
      'cuisine',
      "cuisine -> What is your favorite cuisine? = {\n   US -> American\n   IT -> Italian\n   FR -> French\n}",
    )
    doc = Nokogiri::HTML::DocumentFragment.parse(html)

    expect(doc.children.size).to eq(1)
    expect(doc.search('option').size).to eq(4)
    expect(doc.search('option').first.text).to eq('----')
    expect(doc.search('option').find {|o| o[:selected] }).to be_nil
    expect(doc.search('option.correct').empty?).to be_truthy
    expect(doc.search('option').map{|o| o[:value] }).to eq(["", "US", "IT", "FR"])
    expect(doc.search('option').map{|o| o.text }).to eq(["----", "American", "Italian", "French"])
  end

  it 'generates the proper HTML markup for a multiline select widget with one selected' do
    html = Showoff::Compiler::Form.form_element_select_multiline(
      'foo_cuisine',
      'cuisine',
      "cuisine -> What is your favorite cuisine? = {\n   US -> American\n   IT -> Italian\n   FR -> French\n\n   (XX -> Other)\n}",
    )
    doc = Nokogiri::HTML::DocumentFragment.parse(html)

    expect(doc.children.size).to eq(1)
    expect(doc.search('option').size).to eq(5)
    expect(doc.search('option').first.text).to eq('----')
    expect(doc.search('option.correct').empty?).to be_truthy
    expect(doc.search('option').select {|o| o[:selected] }.size).to eq(1)
    expect(doc.search('option').find {|o| o[:selected] }[:value]).to eq('XX')
    expect(doc.search('option').find {|o| o[:selected] }.text).to eq('Other')
    expect(doc.search('option').map{|o| o[:value] }).to eq(["", "US", "IT", "FR", "XX"])
    expect(doc.search('option').map{|o| o.text }).to eq(["----", "American", "Italian", "French", "Other"])
  end

  it 'generates the proper HTML markup for a multiline select widget with a correct answer' do
    html = Showoff::Compiler::Form.form_element_select_multiline(
      'foo_cuisine',
      'cuisine',
      "cuisine -> What type of cuisine is a baguette? = {\n   US -> American\n   IT -> Italian\n   [FR -> French]\n\n   XX -> Other\n}",
    )
    doc = Nokogiri::HTML::DocumentFragment.parse(html)

    expect(doc.children.size).to eq(1)
    expect(doc.search('option').size).to eq(5)
    expect(doc.search('option').first.text).to eq('----')
    expect(doc.search('option').select {|o| o[:selected] }.size).to eq(0)
    expect(doc.search('option.correct').size).to eq(1)
    expect(doc.search('option.correct').first.text).to eq('French')
    expect(doc.search('option.correct').first[:value]).to eq('FR')
    expect(doc.search('option').map{|o| o[:value] }).to eq(["", "US", "IT", "FR", "XX"])
    expect(doc.search('option').map{|o| o.text }).to eq(["----", "American", "Italian", "French", "Other"])
  end

end




