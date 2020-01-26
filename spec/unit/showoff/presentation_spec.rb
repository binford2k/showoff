RSpec.describe Showoff::Presentation do
  context 'asset management base' do
    before(:each) do
      Showoff::Config.load(File.join(fixtures, 'assets', 'showoff.json'))
      Showoff::State.set(:format, 'web')
      Showoff::State.set(:supplemental, nil)
    end

    it "lists all user styles" do
      presentation = Showoff::Presentation.new({})
      expect(presentation.css_files).to eq ['styles.css']
    end

    it "lists all user scripts" do
      presentation = Showoff::Presentation.new({})
      expect(presentation.js_files).to eq ['scripts.js']
    end

    it "generates a list of all assets" do
      presentation = Showoff::Presentation.new({})
      assets = presentation.assets

      [ 'grumpy_lawyer.jpg',
        'assets/grumpycat.jpg',
        'assets/yellow-brick-road.jpg',
        'styles.css',
        'scripts.js',
      ].each { |file| expect(assets.include? file).to be_truthy }

      [ 'assets/tile.jpg',
        'assets/another.css',
        'assets/another.js',
      ].each { |file| expect(assets.include? file).to be_falsey }
    end
  end

  context 'asset management with additional configs' do
    before(:each) do
      Showoff::Config.load(File.join(fixtures, 'assets', 'extra.json'))
      Showoff::State.set(:format, 'web')
      Showoff::State.set(:supplemental, nil)
    end

    it "lists all user styles" do
      presentation = Showoff::Presentation.new({})
      expect(presentation.css_files).to eq ['styles.css', 'assets/another.css']
    end

    it "lists all user scripts" do
      presentation = Showoff::Presentation.new({})
      expect(presentation.js_files).to eq ['scripts.js', 'assets/another.js']
    end

    it "generates a list of all assets" do
      presentation = Showoff::Presentation.new({})
      assets = presentation.assets

      [ 'grumpy_lawyer.jpg',
        'assets/grumpycat.jpg',
        'assets/yellow-brick-road.jpg',
        'styles.css',
        'scripts.js',
        'assets/tile.jpg',
        'assets/another.css',
        'assets/another.js',
      ].each { |file| expect(assets.include? file).to be_truthy }
    end
  end

  it "generates a web format static presentation" do
    Showoff::Config.load(File.join(fixtures, 'assets', 'showoff.json'))
    Showoff::State.set(:format, 'web')
    presentation = Showoff::Presentation.new({})

    expect(presentation.static).to match(/<meta name="viewport"/)
    expect(presentation.static).to_not match(/The Guidebook/)
  end

  it "generates a print format presentation" do
    Showoff::Config.load(File.join(fixtures, 'assets', 'showoff.json'))
    Showoff::State.set(:format, 'print')
    presentation = Showoff::Presentation.new({})

    expect(presentation.static).to_not match(/<meta name="viewport"/)
    expect(presentation.static).to_not match(/The Guidebook/)
  end

  it "generates supplemental material" do
    Showoff::Config.load(File.join(fixtures, 'assets', 'showoff.json'))
    Showoff::State.set(:format, 'supplemental')
    Showoff::State.set(:supplemental, 'guide')
    presentation = Showoff::Presentation.new({})

    expect(presentation.static).to_not match(/<meta name="viewport"/)
    expect(presentation.static).to match(/The Guidebook/)
  end

end
