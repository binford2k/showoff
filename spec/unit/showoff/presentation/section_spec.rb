RSpec.describe Showoff::Presentation::Section do

  it 'loads files from disk and splits them into slides' do
    Showoff::Config.load(File.join(fixtures, 'slides', 'showoff.json'))
    name, files = Showoff::Config.sections.first
    section = Showoff::Presentation::Section.new(name, files)

    expect(section.name).to eq('.')
    expect(section.slides.size).to eq(5)
    expect(section.slides.map {|slide| slide.id }).to eq(["first", "content1", "content2", "content3", "last"])
  end

end
