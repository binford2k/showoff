RSpec.describe Showoff::Compiler::Form do

  # This is a pretty boring quick "integration" test of the full form.
  # The individual widgets should each be tested individually.
  it "renders examples of all elements" do
#     markdown = File.read(File.join(fixtures, 'forms', 'elements.md'))
#     content  = Tilt[:markdown].new(nil, nil, {}) { markdown }.render
    content = <<-EOF
<h1>This is a slide with some questions</h1>
<p>correct -&gt; This question has a correct answer. =
(=) True
() False</p>
<p>none -&gt; This question has no correct answer. =
() True
() False</p>
<p>named -&gt; This question has named answers. =
() one -&gt; the first answer
(=) two -&gt; the second answer
() three -&gt; the third answer</p>
<p>correctcheck -&gt; This question has a correct answer. =
[=] True
[] False</p>
<p>nonecheck -&gt; This question has no correct answer. =
[] True
[] False</p>
<p>namedcheck -&gt; This question has named answers. =
[] one -&gt; the first answer
[=] two -&gt; the second answer
[] three -&gt; the third answer</p>
<p>name = ___</p>
<p>namelength = ___[50]</p>
<p>nametoken -&gt; What is your name? = ___[50]</p>
<p>comments = [   ]</p>
<p>commentsrows = [   5]</p>
<p>smartphone = () iPhone () Android () other -&gt; Any other phone not listed</p>
<p>awake -&gt; Are you paying attention? = (x) No () Yes</p>
<p>smartphonecheck = [] iPhone [] Android [x] other -&gt; Any other phone not listed</p>
<p>phoneos -&gt; Which phone OS is developed by Google? = {iPhone, [Android], Other }</p>
<p>smartphonecombo = {iPhone, Android, (Other) }</p>
<p>smartphonetoken = {iPhone, Android, (other -&gt; Any other phone not listed) }</p>
<p>cuisine -&gt; What is your favorite cuisine? = { American, Italian, French }</p>
<p>cuisinetoken -&gt; What is your favorite cuisine? = {
US -&gt; American
IT -&gt; Italian
FR -&gt; French
}</p>
EOF

    doc = Nokogiri::HTML::DocumentFragment.parse(content)

    # This call mutates the passed in object
    Showoff::Compiler::Form.render!(doc, :form => 'foo')

    expect(doc).to be_a(Nokogiri::HTML::DocumentFragment)
    expect(doc.search('ul').size).to eq(6)      # each long form radio/check question
    expect(doc.search('li').size).to eq(14)     # all long form radio/check answers
    expect(doc.search('label').size).to eq(41)  # labels for every question/response widget
    expect(doc.search('input').size).to eq(27)  # answers, plus the tool buttons
    expect(doc.search('input[type=radio]').size).to eq(12)    # includes the single line widget
    expect(doc.search('input[type=checkbox]').size).to eq(10) # includes the single line widget
    expect(doc.search('input[type=text]').size).to eq(3)
    expect(doc.search('textarea').size).to eq(2)
    expect(doc.search('select').size).to eq(5)
  end

  # @todo this test suite needs a lotta lotta work. This only scratches the surface
end



