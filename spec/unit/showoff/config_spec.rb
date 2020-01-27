RSpec.describe Showoff::Config do
  context 'base configuration' do
    before(:each) do
      Showoff::Config.load(File.join(fixtures, 'base.json'))
    end

    it "loads configuration from disk" do
      expect(Showoff::Config.root).to eq(fixtures)
      expect(Showoff::Config.keys).to eq(['name', 'description', 'protected', 'version', 'feedback', 'parsers', 'sections', 'markdown', :default, 'pdf_options'])
      expect(Showoff::Config.get('pdf_options')).to eq({:page_size=>"Letter", :orientation=>"Portrait", :print_media_type=>true, :quiet=>false})
    end

    it "calculates relative paths" do
      expect(Showoff::Config.path('foo/bar')).to eq('foo/bar')
      expect(Showoff::Config.path('../fixtures')).to eq(fixtures)
    end

    it "loads proper markdown profile" do
      expect(Showoff::Config.get('markdown')).to eq(:default)
      expect(Showoff::Config.get(:default)).to be_a(Hash)
      expect(Showoff::Config.get(:default)).to eq({
        :autolink          => true,
        :no_intra_emphasis => true,
        :superscript       => true,
        :tables            => true,
        :underline         => true,
        :escape_html       => false,
      })
    end

    it "expands sections" do
      expect(Showoff::Config.sections).to be_a(Hash)
      expect(Showoff::Config.sections['.']).to be_an(Array)
      expect(Showoff::Config.sections['.']).to all be_a(String)
      expect(Showoff::Config.sections['.']).to eq(['Overview.md', 'Content.md', 'Conclusion.md'])
    end
  end

  context 'with named hash sections' do
    before(:each) do
      Showoff::Config.load(File.join(fixtures, 'namedhash.json'))
    end

    it "loads configuration from disk" do
      expect(Showoff::Config.root).to eq(fixtures)
      expect(Showoff::Config.keys).to eq(['name', 'description', 'protected', 'version', 'feedback', 'parsers', 'sections', 'markdown', :default, 'pdf_options'])
      expect(Showoff::Config.get('pdf_options')).to eq({:page_size=>"Letter", :orientation=>"Portrait", :print_media_type=>true, :quiet=>false})
    end

    it "expands sections" do
      expect(Showoff::Config.sections).to be_a(Hash)
      expect(Showoff::Config.sections.keys).to eq(['Overview', 'Content', 'Conclusion'])
      expect(Showoff::Config.sections['Overview']).to all be_a(String)
      expect(Showoff::Config.sections['Overview']).to eq(['title.md', 'intro.md', 'about.md'])
    end
  end

  context 'with configured markdown renderer' do
    before(:each) do
      Showoff::Config.load(File.join(fixtures, 'renderer.json'))
    end

    it "loads configuration from disk" do
      expect(Showoff::Config.root).to eq(fixtures)
      expect(Showoff::Config.keys).to eq(['name', 'description', 'protected', 'version', 'feedback', 'parsers', 'sections', 'markdown', 'maruku', 'pdf_options'])
    end

    it "loads proper markdown profile" do
      expect(Showoff::Config.get('markdown')).to eq('maruku')
      expect(Showoff::Config.get('maruku')).to be_a(Hash)
      expect(Showoff::Config.get('maruku')).to eq({
        :use_tex           => false,
        :png_dir           => 'images',
        :html_png_url      => '/file/images/',
      })
    end
  end

  context 'complex config file' do
    before(:each) do
      Showoff::Config.load(File.join(fixtures, 'complex', 'showoff.json'))
    end

    it "loads configuration from disk" do
      expect(Showoff::Config.root).to eq(File.join(fixtures, 'complex'))

      expect(Showoff::Config.keys).to eq(["name", "description", "pdf_options", "sections", "markdown", :default])
      expect(Showoff::Config.sections['Overview']).to eq(['Overview/objectives.md', 'Overview/overview.md'])
      expect(Showoff::Config.sections['Environment']).to eq(["environment/one.md", "environment/two.md"])
      expect(Showoff::Config.sections['Appendix']).to eq(['Shared/Appendix/appendix.md'])
      expect(Showoff::Config.get('pdf_options')).to eq({:page_size=>"Letter", :orientation=>"Landscape", :print_media_type=>true, :quiet=>true})
    end

  end
end
