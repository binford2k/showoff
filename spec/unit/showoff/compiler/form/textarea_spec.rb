RSpec.describe Showoff::Compiler::Form do

  it "parses textarea markup" do
    content = <<-EOF
<h1>Got any comments?</h1>
<p>comments = [   ]</p>
EOF

    doc = Nokogiri::HTML::DocumentFragment.parse(content)

    expect(doc).to be_a(Nokogiri::HTML::DocumentFragment)
    expect(Showoff::Compiler::Form).to receive(:form_element).with(
      'foo_comments',
      'comments',
      'comments',
      false,
      '[   ]',
      'comments = [   ]',
    ).and_return('')

    # This call mutates the passed in object and invokes the form rendering
    Showoff::Compiler::Form.render!(doc, :form => 'foo')
  end

  it "renders textareas from markup" do
    expect(Showoff::Compiler::Form).to receive(:form_element_textarea).with(
      'foo_comments',
      'comments',
      '',
    ).and_return('')

    Showoff::Compiler::Form.form_element(
      'foo_comments',
      'comments',
      'comments',
      false,
      '[   ]',
      'comments = [   ]',
    )
  end

  it 'generates the proper HTML markup for a textarea' do
    html = Showoff::Compiler::Form.form_element_textarea(
      'foo_comments',
      'comments',
      '',
    )
    doc  = Nokogiri::HTML::DocumentFragment.parse(html)
    text = doc.children.first

    expect(doc.children.size).to eq(1)
    expect(text.node_name).to eq('textarea')
    expect(text[:id]).to eq('foo_comments_response')
    expect(text[:name]).to eq('comments')
    expect(text[:rows]).to eq('3')
  end

################################################################################

  it "parses textarea markup with rows" do
    content = <<-EOF
<h1>Got any comments?</h1>
<p>comments = [   5]</p>
EOF

    doc = Nokogiri::HTML::DocumentFragment.parse(content)

    expect(doc).to be_a(Nokogiri::HTML::DocumentFragment)
    expect(Showoff::Compiler::Form).to receive(:form_element).with(
      'foo_comments',
      'comments',
      'comments',
      false,
      '[   5]',
      'comments = [   5]',
    ).and_return('')

    # This call mutates the passed in object and invokes the form rendering
    Showoff::Compiler::Form.render!(doc, :form => 'foo')
  end

  it "renders textareas from markup with rows" do
    expect(Showoff::Compiler::Form).to receive(:form_element_textarea).with(
      'foo_comments',
      'comments',
      '5',
    ).and_return('')

    Showoff::Compiler::Form.form_element(
      'foo_comments',
      'comments',
      'comments',
      false,
      '[   5]',
      'comments = [   5]',
    )
  end

  it 'generates the proper HTML markup for a textarea with rows' do
    html = Showoff::Compiler::Form.form_element_textarea(
      'foo_comments',
      'comments',
      '5',
    )
    doc  = Nokogiri::HTML::DocumentFragment.parse(html)
    text = doc.children.first

    expect(doc.children.size).to eq(1)
    expect(text.node_name).to eq('textarea')
    expect(text[:id]).to eq('foo_comments_response')
    expect(text[:name]).to eq('comments')
    expect(text[:rows]).to eq('5')
  end

end




