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

  it 'marks the proper answer as correct'
  it 'selects the proper default option'
  # @todo this test suite needs a lotta lotta work. This only scratches the surface
end




