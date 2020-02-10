RSpec.describe Showoff::Compiler::TableOfContents do

  it "generates a table of contents" do
    html = File.read(File.join(fixtures, 'glossary_toc', 'content.html'))
    doc  = Nokogiri::HTML::DocumentFragment.parse(html)

    Showoff::Compiler::TableOfContents.generate!(doc)

    expect(doc.search('.slide.toc').size).to eq(1)
    expect(doc.search('ol#toc').size).to eq(1)
    expect(doc.search('ol#toc li').size).to eq(3)
    expect(doc.search('ol#toc li a')[0][:href]).to eq('#content2')
    expect(doc.search('ol#toc li a')[1][:href]).to eq('#content3')
    expect(doc.search('ol#toc li a')[2][:href]).to eq('#content4')
    expect(doc.search('ol#toc li a')[0].text).to eq('Glossary and TOC Demo')
    expect(doc.search('ol#toc li a')[1].text).to eq('General Glossary')
    expect(doc.search('ol#toc li a')[2].text).to eq('This is a named glossary')
  end

end
