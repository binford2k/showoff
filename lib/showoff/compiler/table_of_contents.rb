# adds table of content generation to the compiler
class Showoff::Compiler::TableOfContents

  # Render a table of contents
  #
  # @param doc [Nokogiri::HTML::DocumentFragment]
  #     The presentation document
  #
  # @return [Nokogiri::HTML::DocumentFragment]
  #     The presentation DOM with the table of contents rendered.
  #
  # @see
  #     https://github.com/puppetlabs/showoff/blob/3f43754c84f97be4284bb34f9bc7c42175d45226/lib/showoff.rb#L747-L768
  def self.generate!(doc)
    container = doc.search('p').find {|p| p.text == '~~~TOC~~~' }
    return doc unless container

    section = nil
    toc = Nokogiri::XML::Node.new('ol', doc)
    toc.set_attribute('id', 'toc')

    doc.search('div.slide:not(.toc)').each do |slide|
      next if slide.search('.content').first.classes.include? 'cover'

      heads = slide.search('div.content h1:not(.section_title)')
      title = heads.empty? ? slide['data-title'] : heads.first.text
      href  = "##{slide['id']}"

      entry = Nokogiri::XML::Node.new('li', doc)
      entry.add_class('tocentry')
      link  = Nokogiri::XML::Node.new('a', doc)
      link.set_attribute('href', href)
      link.content = title
      entry.add_child(link)

      if (section and slide['data-section'] == section['data-section'])
        section.add_child(entry)
      else
        section = Nokogiri::XML::Node.new('ol', doc)
        section.add_class('major')
        section.set_attribute('data-section', slide['data-section'])
        entry.add_child(section)
        toc.add_child(entry)
      end

    end
    container.replace(toc)

    doc
  end
end
