RSpec.describe Showoff::Locale do
  before(:each) do
    Showoff::Config.load(File.join(fixtures, 'i18n'), 'showoff.json')
  end

  it "selects a default content language" do
    expect(I18n.available_locales.include?(Showoff::Locale.setContentLocale)).to be_truthy
  end

  it "allows user to set content language" do
    Showoff::Locale.setContentLocale(:de)
    expect(Showoff::Locale.contentLocale).to eq(:de)
  end

  it "allows user to set content language with extended codes" do
    Showoff::Locale.setContentLocale('de-li')
    expect(Showoff::Locale.contentLocale).to eq(:de)
  end

  it "returns the name of a language code" do
    Showoff::Locale.setContentLocale(:de)
    expect(Showoff::Locale.languageName).to eq('German')
  end

  it "interpolates the proper content path when it exists" do
    Showoff::Locale.setContentLocale(:de)
    expect(Showoff::Locale.contentPath).to eq(File.join(fixtures, 'i18n', 'locales', 'de'))
  end

  it "interpolates the proper content path when it does not exist" do
    Showoff::Locale.setContentLocale(:ja)
    expect(Showoff::Locale.contentPath).to eq(File.join(fixtures, 'i18n'))
  end

  it "returns the appropriate content language hash" do
    expect(Showoff::Locale.contentLanguages).to eq({"de"=>"German", "en"=>"English", "es"=>"Spanish; Castilian", "fr"=>"French", "ja"=>"Japanese"})
  end

  it "returns UI string translations" do
    expect(Showoff::Locale.translations[:menu][:title]).to be_a(String)
  end

  it "retrieves the proper translations from strings.json" do
    Showoff::Locale.setContentLocale(:de)
    expect(Showoff::Locale.userTranslations).to eq({'greeting' => 'Hallo!'})
  end

  it "retrieves an empty hash from strings.json when the key doesn't exist" do
    Showoff::Locale.setContentLocale(:nl)
    expect(Showoff::Locale.userTranslations).to eq({})
  end

end
