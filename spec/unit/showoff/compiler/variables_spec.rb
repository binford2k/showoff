RSpec.describe Showoff::Compiler::Variables do

  it "interpolates simple tokens" do
    content = <<-EOF
# This is a simple markdown slide

~~~PAGEBREAK~~~

~~~FORM:boogerwoog~~~

[fa-podcast]
[fa-smile-o some classes]

``` Ruby and some other classes
puts "hello"
```

~~~TEST~~~
~~~TEST2~~~
EOF

    # This call mutates the passed in object
    Showoff::Compiler::Variables.interpolate!(content)

    expect(content).to be_a(String)
    expect(content).to match(/<div class="pagebreak">continued...<\/div>/)
    expect(content).to match(/<div class="form wrapper" title="boogerwoog"><\/div>/)
    expect(content).to match(/<i class="fa fa-podcast "><\/i>/)
    expect(content).to match(/<i class="fa fa-smile-o some classes"><\/i>/)
    expect(content).to match(/``` Ruby:and:some:other:classes/)
    expect(content).to match(/\\~~~TEST~~~/)
    expect(content).to match(/\n\n\\~~~TEST~~~\n\n/)
  end

  it "interpolates slide counters" do
     content = <<-EOF
# This is a simple markdown slide

current:~~~CURRENT_SLIDE~~~

major:~~~SECTION:MAJOR~~~

minor:~~~SECTION:MINOR~~~

EOF
    content2 = content.dup

    Showoff::State.set(:slide_count, 23)
    Showoff::State.set(:section_major, 1)

    # This call mutates the passed in object
    Showoff::Compiler::Variables.interpolate!(content)
    expect(content).to be_a(String)
    expect(content).to match(/current:23/)
    expect(content).to match(/major:1/)
    expect(content).to match(/minor:1/)

    # now interpolate the "second slide" and ensure that the minor counter incremented
    Showoff::Compiler::Variables.interpolate!(content2)
    expect(content2).to match(/major:1/)
    expect(content2).to match(/minor:2/)
  end

end
