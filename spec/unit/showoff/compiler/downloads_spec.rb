RSpec.describe Showoff::Compiler::Downloads do
  content = <<-EOF
<h1>This is a simple HTML slide with download tags</h1>
<p>Here are a few tags that should be transformed to attachments</p>
<p class="download">link/to/one.txt
.download link/to/two.txt all
.download link/to/three.txt prev
.download link/to/four.txt current
.download link/to/five.txt next</p>
EOF

  tests = {
    :all  => {:slide =>  0, :files => ['link/to/two.txt']},
    :pre  => {:slide => 21, :files => []},
    :prev => {:slide => 22, :files => ['link/to/three.txt']},
    :curr => {:slide => 23, :files => ['link/to/four.txt']},
    :next => {:slide => 24, :files => ['link/to/one.txt', 'link/to/five.txt']},
    :post => {:slide => 25, :files => []},
  }

  tests.each do |period, data|
    it "transforms download tags to #{period} slide attachments" do
      doc = Nokogiri::HTML::DocumentFragment.parse(content)

      Showoff::State.reset()
      Showoff::State.set(:slide_count, 23)

      # This call mutates the passed in object
      Showoff::Compiler::Downloads.scanForFiles!(doc, :name => 'foo')
      elements = doc.search('p')
      slide = data[:slide]
      files = data[:files]

      expect(doc).to be_a(Nokogiri::HTML::DocumentFragment)
      expect(elements.length).to eq(1)
      expect(Showoff::Compiler::Downloads.getFiles(slide)).to eq([])

      Showoff::Compiler::Downloads.enableFiles(slide)
      expect(Showoff::Compiler::Downloads.getFiles(slide).size).to eq(files.length)
      expect(Showoff::Compiler::Downloads.getFiles(slide).map{|a| a[:source] }).to all eq('foo')
      expect(Showoff::Compiler::Downloads.getFiles(slide).map{|a| a[:slidenum] }).to all eq(23)
      expect(Showoff::Compiler::Downloads.getFiles(slide).map{|a| a[:file] }).to eq(files)
    end
  end

  it "removes a paragraph of download tags from document" do
    doc = Nokogiri::HTML::DocumentFragment.parse(content)
    Showoff::State.set(:slide_count, 23)

    # This call mutates the passed in object
    Showoff::Compiler::Downloads.scanForFiles!(doc, :name => 'foo')
    elements = doc.search('p')

    expect(doc).to be_a(Nokogiri::HTML::DocumentFragment)
    expect(elements.length).to eq(1)
  end

  it "returns an empty array for a blank stack" do
    Showoff::State.reset()

    expect(Showoff::Compiler::Downloads.getFiles(12)).to eq([])
  end

  it "pushes a file onto the attachment stack" do
    Showoff::State.reset()

    expect(Showoff::Compiler::Downloads.pushFile(12, 12, 'foo', 'path/to/file.txt')[:enabled]).to be_falsey
    expect(Showoff::Compiler::Downloads.getFiles(12)).to eq([])
    Showoff::State.get(:downloads)[12] = {:enabled=>false, :slides=>[{:slidenum=>12, :source=>"foo", :file=>"path/to/file.txt"}]}
  end

  it "enables a download properly" do
    Showoff::State.reset()

    expect(Showoff::Compiler::Downloads.pushFile(12, 12, 'foo', 'path/to/file.txt')[:enabled]).to be_falsey
    expect(Showoff::Compiler::Downloads.getFiles(12)).to eq([])

    Showoff::Compiler::Downloads.enableFiles(12)
    expect(Showoff::Compiler::Downloads.getFiles(12)).to eq([{:slidenum=>12, :source=>"foo", :file=>"path/to/file.txt"}])
  end

end


