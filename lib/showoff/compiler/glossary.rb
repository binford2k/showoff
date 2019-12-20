# adds glossary processing to the compiler
class Showoff::Compiler::Glossary

  # Scan for glossary links and add definitions. This does not yet create the
  # glossary page at the end.
  #
  # @param doc [Nokogiri::HTML::DocumentFragment]
  #     The slide document
  #
  # @return [Nokogiri::HTML::DocumentFragment]
  #     The slide DOM with all glossary entries rendered.
  #
  # @see
  #     https://github.com/puppetlabs/showoff/blob/3f43754c84f97be4284bb34f9bc7c42175d45226/lib/showoff.rb#L650-L706
  def self.render(doc)

    # Find all callout style definitions on the slide and add links to the glossary page
    doc.search('.callout.glossary').each do |item|
      next unless item.content =~ /^([^|]+)\|([^:]+):(.*)$/
      item['data-term']   = $1
      item['data-target'] = $2
      item['data-text']   = $3.strip
      item.content        = $3.strip

      glossary = (item.attr('class').split - ['callout', 'glossary']).first
      address  = glossary ? "#{glossary}/#{$2}" : $2
      frag     = "<a class=\"processed label\" href=\"glossary://#{address}\">#{$1}</a>"

      item.prepend_child(frag)
    end

    # Find glossary links and add definitions to the notes
    doc.search('a').each do |link|
      next unless link['href']
      next unless link['href'].start_with? 'glossary://'
      next if link.classes.include? 'processed'

      link.add_class('term')

      term = link.content
      text = link['title']
      href = link['href']

      target, name  = href.slice('glossary://').split('/')

      label = link.clone
      label.add_class('label processed')

      definition = Nokogiri::XML::Node.new('p', doc).add_class("callout glossary #{name}")
      definition.set_attribute('data-term', term)
      definition.set_attribute('data-text', text)
      definition.set_attribute('data-target', target)
      definition.content = text
      definition.prepend_child(label)

      # @todo this duplication is annoying but it makes it less order dependent
      doc.add_child '<div class="notes-section notes"></div>' if doc.search('div.notes-section.notes').empty?
      doc.add_child '<div class="notes-section handouts"></div>' if doc.search('div.notes-section.handouts').empty?

      [doc.css('div.notes-section.notes'), doc.css('div.notes-section.handouts')].each do |section|
        section.first.add_child(definition.clone)
      end

    end

    doc
  end

end
