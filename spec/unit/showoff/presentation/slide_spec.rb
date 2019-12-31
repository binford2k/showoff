RSpec.describe Showoff::Presentation::Slide do

  it 'parses class and form metadata settings' do
    context = {:section=>".", :name=>"first.md", :seq=>nil}
    options = "first title form=noodles"
    content = <<-EOF
# First slide

This little piggy went to market.
EOF

    subject = Showoff::Presentation::Slide.new(options, content, context)

    expect(subject.classes).to eq(["first", "title"])
    expect(subject.form).to eq('noodles')
    expect(subject.id).to eq('first')
    expect(subject.name).to eq('first')
    expect(subject.ref).to eq('first')
    expect(subject.section).to eq('.')
    expect(subject.section_title).to eq('.')
    expect(subject.seq).to be_nil
    expect(subject.transition).to eq('none')
  end

  it 'parses a background metadata setting' do
    context = {:section=>".", :name=>"content.md", :seq=>1}
    options = "[bg=bg.png] one"
    content = <<-EOF
# One

This little piggy stayed home.
EOF

    subject = Showoff::Presentation::Slide.new(options, content, context)

    expect(subject.classes).to eq(["one"])
    expect(subject.id).to eq('content1')
    expect(subject.name).to eq('content')
    expect(subject.ref).to eq('content:1')
    expect(subject.seq).to eq(1)
    expect(subject.background).to eq('bg.png')
  end

  it 'parses a slide class and sets section title' do
    context = {:section=>".", :name=>"content.md", :seq=>2}
    options = "two piggy subsection"
    content = <<-EOF
# Two

This little piggy had roast beef.
EOF

    subject = Showoff::Presentation::Slide.new(options, content, context)

    expect(subject.classes).to eq(["two", "piggy", "subsection"])
    expect(subject.id).to eq('content2')
    expect(subject.name).to eq('content')
    expect(subject.ref).to eq('content:2')
    expect(subject.section).to eq('.')
    expect(subject.section_title).to eq('Two')
    expect(subject.seq).to eq(2)
  end

  it 'parses a transition as an option and maintains section title' do
    context = {:section=>".", :name=>"content.md", :seq=>3}
    options = "[transition=fade] three"
    content = <<-EOF
# Three

This little piggy had none.
EOF

    subject = Showoff::Presentation::Slide.new(options, content, context)

    expect(subject.classes).to eq(["three"])
    expect(subject.id).to eq('content3')
    expect(subject.name).to eq('content')
    expect(subject.ref).to eq('content:3')
    expect(subject.section).to eq('.')
    expect(subject.section_title).to eq('Two')
    expect(subject.seq).to eq(3)
    expect(subject.transition).to eq('fade')
  end

  it 'parses a transition as a weirdo class' do
    context = {:section=>".", :name=>"last.md", :seq=>nil}
    options = "last bigtext transition=fade"
    content = <<-EOF
# Last

This little piggy cried wee wee wee all the way home.
EOF

    subject = Showoff::Presentation::Slide.new(options, content, context)

    expect(subject.classes).to eq(["last", "bigtext"])
    expect(subject.id).to eq('last')
    expect(subject.name).to eq('last')
    expect(subject.ref).to eq('last')
    expect(subject.seq).to be_nil
    expect(subject.transition).to eq('fade')
  end

  it 'blacklists known bad classes' do
    context = {:section=>".", :name=>"last.md", :seq=>nil}
    options = "last bigtext transition=fade"
    content = <<-EOF
# Last

This little piggy cried wee wee wee all the way home.
EOF

    subject = Showoff::Presentation::Slide.new(options, content, context)

    expect(subject.classes).to eq(["last", "bigtext"])
    expect(subject.slideClasses).to eq(["last"])
  end

  it 'maintains proper slide counts' do
    content = <<-EOF
# First slide
EOF

    Showoff::State.reset
    Showoff::Presentation::Slide.new('', content, {:section=>".", :name=>"state.md", :seq=>1}).render
    Showoff::Presentation::Slide.new('', content, {:section=>".", :name=>"state.md", :seq=>2}).render
    Showoff::Presentation::Slide.new('', content, {:section=>".", :name=>"state.md", :seq=>3}).render
    Showoff::Presentation::Slide.new('', content, {:section=>".", :name=>"state.md", :seq=>4}).render

    expect(Showoff::State.get(:slide_count)).to eq(4)
  end

end
