RSpec.describe Showoff::Compiler::Form do

  it "parses single line text field markup" do
    content = <<-EOF
<h1>What's your name?</h1>
<p>name = ___</p>
EOF

    doc = Nokogiri::HTML::DocumentFragment.parse(content)

    expect(doc).to be_a(Nokogiri::HTML::DocumentFragment)
    expect(Showoff::Compiler::Form).to receive(:form_element).with(
      'foo_name',
      'name',
      'name',
      false,
      '___',
      'name = ___',
    ).and_return('')

    # This call mutates the passed in object and invokes the form rendering
    Showoff::Compiler::Form.render!(doc, :form => 'foo')
  end

  it "renders text fields from markup" do
    expect(Showoff::Compiler::Form).to receive(:form_element_text).with(
      'foo_name',
      'name',
      nil,
    ).and_return('')

    Showoff::Compiler::Form.form_element(
      'foo_name',
      'name',
      'name',
      false,
      '___',
      'name = ___',
    )
  end

  it 'generates the proper HTML markup for a text field' do
    html = Showoff::Compiler::Form.form_element_text(
      'foo_name',
      'name',
      nil,
    )
    doc  = Nokogiri::HTML::DocumentFragment.parse(html)
    text = doc.children.first

    expect(doc.children.size).to eq(1)
    expect(text.node_name).to eq('input')
    expect(text[:type]).to eq('text')
    expect(text[:id]).to eq('foo_name_response')
    expect(text[:name]).to eq('name')
    expect(text[:size]).to eq('')
  end

################################################################################

  it "parses single line text field markup with length" do
    content = <<-EOF
<h1>What's your name?</h1>
<p>name = ___[50]</p>
EOF

    doc = Nokogiri::HTML::DocumentFragment.parse(content)

    expect(doc).to be_a(Nokogiri::HTML::DocumentFragment)
    expect(Showoff::Compiler::Form).to receive(:form_element).with(
      'foo_name',
      'name',
      'name',
      false,
      '___[50]',
      'name = ___[50]',
    ).and_return('')

    # This call mutates the passed in object and invokes the form rendering
    Showoff::Compiler::Form.render!(doc, :form => 'foo')
  end

  it "renders text fields from markup with length" do
    expect(Showoff::Compiler::Form).to receive(:form_element_text).with(
      'foo_name',
      'name',
      '50',
    ).and_return('')

    Showoff::Compiler::Form.form_element(
      'foo_name',
      'name',
      'name',
      false,
      '___[50]',
      'name = ___[50]',
    )
  end

  it 'generates the proper HTML markup for a text field' do
    html = Showoff::Compiler::Form.form_element_text(
      'foo_name',
      'name',
      '50',
    )
    doc  = Nokogiri::HTML::DocumentFragment.parse(html)
    text = doc.children.first

    expect(doc.children.size).to eq(1)
    expect(text.node_name).to eq('input')
    expect(text[:type]).to eq('text')
    expect(text[:id]).to eq('foo_name_response')
    expect(text[:name]).to eq('name')
    expect(text[:size]).to eq('50')
  end

end




