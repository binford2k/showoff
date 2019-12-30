RSpec.describe Showoff::Compiler do

  it "resolves the default renderer properly" do
    expect(Showoff::Config).to receive(:get).with('markdown').and_return(:default)
    expect(Showoff::Config).to receive(:get).with(:default).and_return({})
    expect(Tilt).to receive(:prefer).with(Tilt::RedcarpetTemplate, 'markdown')
    expect(Tilt.template_for('markdown')).to eq(Tilt::RedcarpetTemplate)

    Showoff::Compiler.new({:name => 'foo'})
  end

  it "resolves a configured renderer" do
    expect(Showoff::Config).to receive(:get).with('markdown').and_return('commonmarker')
    expect(Showoff::Config).to receive(:get).with('commonmarker').and_return({})
    expect(Tilt).to receive(:prefer).with(Tilt::CommonMarkerTemplate, 'markdown')
    #expect(Tilt.template_for('markdown')).to eq(Tilt::CommonMarkerTemplate)  # polluted state doesn't allow this to succeed

    Showoff::Compiler.new({:name => 'foo'})
  end

  it "errors when configured with an unknown renderer" do
    expect(Showoff::Config).to receive(:get).with('markdown').and_return('wrong')
    expect(Showoff::Config).to receive(:get).with('wrong').and_return({})

    expect { Showoff::Compiler.new({:name => 'foo'}) }.to raise_error(StandardError, 'Unsupported markdown renderer')
  end

  # note that this test is basically a simple integration test of all the compiler components.
  it "renders content as expected" do
    Showoff::Config.load(fixtures, 'base.json')

    content, notes = Showoff::Compiler.new({:name => 'foo'}).render("#Hi there!\n\n.callout The Internet is serious business.")

    expect(content).to be_a(Nokogiri::HTML::DocumentFragment)
    expect(notes).to be_a(Nokogiri::XML::NodeSet)
    expect(notes.empty?).to be_truthy

    expect(content.search('h1').first.text).to eq('Hi there!')
    expect(content.search('p').first.text).to eq('The Internet is serious business.')
    expect(content.search('p').first.classes).to eq(['callout'])
  end

end
