RSpec.describe Showoff::Compiler::Form do

  it "parses single line radio button markup" do
#     markdown = File.read(File.join(fixtures, 'forms', 'radios.md'))
#     content  = Tilt[:markdown].new(nil, nil, {}) { markdown }.render
    content = <<-EOF
<h1>Testing radio buttons</h1>
<p>smartphone = () iPhone () Android () other -&gt; Any other phone not listed</p>
EOF

    doc = Nokogiri::HTML::DocumentFragment.parse(content)

    expect(doc).to be_a(Nokogiri::HTML::DocumentFragment)
    expect(Showoff::Compiler::Form).to receive(:form_element).with(
      'foo_smartphone',
      'smartphone',
      'smartphone',
      false,
      '() iPhone () Android () other -> Any other phone not listed',
      'smartphone = () iPhone () Android () other -> Any other phone not listed',
    ).and_return('')

    # This call mutates the passed in object and invokes the form rendering
    Showoff::Compiler::Form.render!(doc, :form => 'foo')
  end

  it "renders radio buttons from single line markup" do
    expect(Showoff::Compiler::Form).to receive(:form_element_radio).with(
      'foo_smartphone',
      'smartphone',
      [["", "iPhone "], ["", "Android "], ["", "other -> Any other phone not listed"]],
    ).and_return('')

    Showoff::Compiler::Form.form_element(
      'foo_smartphone',
      'smartphone',
      'smartphone',
      false,
      '() iPhone () Android () other -> Any other phone not listed',
      'smartphone = () iPhone () Android () other -> Any other phone not listed',
    )
  end

  it 'generates the proper HTML markup for a radio button set' do
    html = Showoff::Compiler::Form.form_element_check_or_radio_set(
      'radio',
      'foo_smartphone',
      'smartphone',
      [["", "iPhone "], ["", "Android "], ["", "other -> Any other phone not listed"]],
    )
    doc = Nokogiri::HTML::DocumentFragment.parse(html)

    expect(doc.children.size).to eq(6)
    expect(doc.search('label.response').size).to eq(3)
    expect(doc.search('input[type=radio].response').size).to eq(3)
    expect(doc.search('#foo_smartphone_iPhone').size).to eq(1)
    expect(doc.search('#foo_smartphone_Android').size).to eq(1)
    expect(doc.search('#foo_smartphone_other').size).to eq(1)
    expect(doc.search('input[type=radio].response.correct').empty?).to be_truthy
    expect(doc.search('input[type=radio]').select {|i| i.attribute('checked') }.empty?).to be_truthy
  end

################################################################################

  it "parses single line tokenized name radio button markup" do
#     markdown = File.read(File.join(fixtures, 'forms', 'radios.md'))
#     content  = Tilt[:markdown].new(nil, nil, {}) { markdown }.render
    content = <<-EOF
<h1>Testing radio buttons</h1>
<p>awake -&gt; Are you paying attention? = (x) No () Yes</p>
EOF

    doc = Nokogiri::HTML::DocumentFragment.parse(content)

    expect(doc).to be_a(Nokogiri::HTML::DocumentFragment)
    expect(Showoff::Compiler::Form).to receive(:form_element).with(
      'foo_awake',
      'awake',
      'Are you paying attention?',
      false,
      '(x) No () Yes',
      'awake -> Are you paying attention? = (x) No () Yes',
    ).and_return('')

    # This call mutates the passed in object and invokes the form rendering
    Showoff::Compiler::Form.render!(doc, :form => 'foo')
  end

  it "renders radio buttons from single line markup with a tokenized name" do
    expect(Showoff::Compiler::Form).to receive(:form_element_radio).with(
      'foo_awake',
      'awake',
      [["x", "No "], ["", "Yes"]],
    ).and_return('')

    Showoff::Compiler::Form.form_element(
      'foo_awake',
      'awake',
      'Are you paying attention?',
      false,
      '(x) No () Yes',
      'awake -> Are you paying attention? = (x) No () Yes',
    )
  end

  it 'generates the proper HTML markup for a tokenized name radio button set' do
    html = Showoff::Compiler::Form.form_element_check_or_radio_set(
      'radio',
      'foo_awake',
      'awake',
      [["x", "No "], ["", "Yes"]],
    )
    doc = Nokogiri::HTML::DocumentFragment.parse(html)

    expect(doc.children.size).to eq(4)
    expect(doc.search('label.response').size).to eq(2)
    expect(doc.search('input[type=radio].response').size).to eq(2)
    expect(doc.search('#foo_awake_No').size).to eq(1)
    expect(doc.search('#foo_awake_Yes').size).to eq(1)
    expect(doc.search('input[type=radio].response.correct').empty?).to be_truthy
    expect(doc.search('input[type=radio]').select {|i| i.attribute('checked') }.size).to eq(1)
  end

################################################################################

  it "parses multi line radio button markup" do
    content = <<-EOF
<h1>Testing radio buttons</h1>
<p>continent -&gt; Which continent is largest? =
() Africa
() Americas
(=) Asia
() Australia
() Europe</p>
EOF

    doc = Nokogiri::HTML::DocumentFragment.parse(content)

    expect(doc).to be_a(Nokogiri::HTML::DocumentFragment)
    expect(Showoff::Compiler::Form).to receive(:form_element).with(
      'foo_continent',
      'continent',
      'Which continent is largest?',
      false,
      '',
      "continent -> Which continent is largest? =\n() Africa\n() Americas\n(=) Asia\n() Australia\n() Europe",
    ).and_return('')

    # This call mutates the passed in object and invokes the form rendering
    Showoff::Compiler::Form.render!(doc, :form => 'foo')
  end

  it "renders radio buttons from multi line markup" do
    expect(Showoff::Compiler::Form).to receive(:form_element_multiline).with(
      'foo_continent',
      'continent',
      "continent -> Which continent is largest? =\n() Africa\n() Americas\n(=) Asia\n() Australia\n() Europe",
    ).and_return('')

    Showoff::Compiler::Form.form_element(
      'foo_continent',
      'continent',
      'Which continent is largest?',
      false,
      '',
      "continent -> Which continent is largest? =\n() Africa\n() Americas\n(=) Asia\n() Australia\n() Europe",
    )
  end

  it 'renders items for a multiline radio button set' do
    expect(Showoff::Compiler::Form).to receive(:form_element_check_or_radio).with(
      'radio',
      'foo_continent',
      'continent',
      'Africa',
      'Africa',
      '',
    ).and_return('x')
    expect(Showoff::Compiler::Form).to receive(:form_element_check_or_radio).with(
      'radio',
      'foo_continent',
      'continent',
      'Americas',
      'Americas',
      '',
    ).and_return('x')
    expect(Showoff::Compiler::Form).to receive(:form_element_check_or_radio).with(
      'radio',
      'foo_continent',
      'continent',
      'Asia',
      'Asia',
      '=',
    ).and_return('x')
    expect(Showoff::Compiler::Form).to receive(:form_element_check_or_radio).with(
      'radio',
      'foo_continent',
      'continent',
      'Australia',
      'Australia',
      '',
    ).and_return('x')
    expect(Showoff::Compiler::Form).to receive(:form_element_check_or_radio).with(
      'radio',
      'foo_continent',
      'continent',
      'Europe',
      'Europe',
      '',
    ).and_return('x')

    html = Showoff::Compiler::Form.form_element_multiline(
      'foo_continent',
      'continent',
      "continent -> Which continent is largest? =\n() Africa\n() Americas\n(=) Asia\n() Australia\n() Europe",
    )
    doc = Nokogiri::HTML::DocumentFragment.parse(html)

    expect(doc.search('li').size).to eq(5)
  end

  it 'generates the proper HTML markup for a multiline radio button element' do
    html = Showoff::Compiler::Form.form_element_check_or_radio(
      'radio',
      'foo_continent',
      'continent',
      'Africa',
      'Africa',
      '',
    )
    doc = Nokogiri::HTML::DocumentFragment.parse(html)

    expect(doc.children.size).to eq(2)
    expect(doc.search('label.response').size).to eq(1)
    expect(doc.search('label.response').first.text).to eq('Africa')
    expect(doc.search('input[type=radio].response').size).to eq(1)
    expect(doc.search('input[type=radio].response').first[:value]).to eq('Africa')

    expect(doc.search('#foo_continent_Africa').size).to eq(1)
    expect(doc.search('input[type=radio].response.correct').empty?).to be_truthy
    expect(doc.search('input[type=radio]').select {|i| i.attribute('checked') }.size).to eq(0)
  end

  it 'generates the proper HTML markup for a multiline correct radio button element' do
    html = Showoff::Compiler::Form.form_element_check_or_radio(
      'radio',
      'foo_continent',
      'continent',
      'Asia',
      'Asia',
      '=',
    )
    doc = Nokogiri::HTML::DocumentFragment.parse(html)

    expect(doc.children.size).to eq(2)
    expect(doc.search('label.response').size).to eq(1)
    expect(doc.search('label.response').first.text).to eq('Asia')
    expect(doc.search('input[type=radio].response').size).to eq(1)
    expect(doc.search('input[type=radio].response').first[:value]).to eq('Asia')

    expect(doc.search('#foo_continent_Asia').size).to eq(1)
    expect(doc.search('input[type=radio].response').size).to eq(1)
    expect(doc.search('input[type=radio]').select {|i| i.attribute('checked') }.size).to eq(0)
  end

  # @todo this test suite needs a lotta lotta work. This only scratches the surface
end




