RSpec.describe Showoff::Compiler::I18n do
  before(:each) do
    Showoff::Config.load(File.join(fixtures, 'i18n', 'showoff.json'))
  end

  it "selects the correct language" do
    content = <<-EOF
# This is a simple markdown slide

~~~LANG:en~~~
Hello, world!
~~~ENDLANG~~~

~~~LANG:fr~~~
Bonjour tout le monde!
~~~ENDLANG~~~
EOF

    Showoff::Locale.setContentLocale(:fr)

    # This call mutates the passed in object
    Showoff::Compiler::I18n.selectLanguage!(content)

    expect(content).to be_a(String)
    expect(content).to match(/Bonjour tout le monde!/)
    expect(content).not_to match(/Hello, world!/)
    expect(content).not_to match(/~~~LANG:[\w-]+~~~/)
    expect(content).not_to match(/~~~ENDLANG~~~/)
  end

  it "includes no languages if they don't match" do
    content = <<-EOF
# This is a simple markdown slide

~~~LANG:en~~~
Hello, world!
~~~ENDLANG~~~

~~~LANG:fr~~~
Bonjour tout le monde!
~~~ENDLANG~~~
EOF

    Showoff::Locale.setContentLocale(:js)

    # This call mutates the passed in object
    Showoff::Compiler::I18n.selectLanguage!(content)

    expect(content).to be_a(String)
    expect(content).not_to match(/Bonjour tout le monde!/)
    expect(content).not_to match(/Hello, world!/)
    expect(content).not_to match(/~~~LANG:[\w-]+~~~/)
    expect(content).not_to match(/~~~ENDLANG~~~/)
  end

  it "includes no languages if local is unset" do
    content = <<-EOF
# This is a simple markdown slide

~~~LANG:en~~~
Hello, world!
~~~ENDLANG~~~

~~~LANG:fr~~~
Bonjour tout le monde!
~~~ENDLANG~~~
EOF

    # This call mutates the passed in object
    Showoff::Compiler::I18n.selectLanguage!(content)

    expect(content).to be_a(String)
    expect(content).not_to match(/Bonjour tout le monde!/)
    expect(content).not_to match(/Hello, world!/)
    expect(content).not_to match(/~~~LANG:[\w-]+~~~/)
    expect(content).not_to match(/~~~ENDLANG~~~/)
  end

end
