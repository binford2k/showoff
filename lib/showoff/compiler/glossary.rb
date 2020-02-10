# adds glossary processing to the compiler
class Showoff::Compiler::Glossary

  # Scan for glossary links and add definitions. This does not create the
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
  def self.render!(doc)

    # Find all callout style definitions on the slide and add links to the glossary page
    doc.search('.callout.glossary').each do |item|
      next unless item.content =~ /^([^|]+)\|([^:]+):(.*)$/
      item['data-term']   = $1
      item['data-target'] = $2
      item['data-text']   = $3.strip
      item.content        = $3.strip

      glossary = (item.attr('class').split - ['callout', 'glossary']).first
      address  = glossary ? "#{glossary}/#{$2}" : $2

      link = Nokogiri::XML::Node.new('a', doc)
      link.add_class('processed label')
      link.set_attribute('href', "glossary://#{address}")
      link.content = $1

      item.prepend_child(link)
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

      parts  = href.split('/')
      target = parts.pop
      name   = parts.pop # either the glossary name or nil

      label = link.clone
      label.add_class('label processed')

      definition = Nokogiri::XML::Node.new('p', doc)
      definition.add_class("callout glossary #{name}")
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

  # Generate and add the glossary page
  #
  # @param doc [Nokogiri::HTML::DocumentFragment]
  #     The presentation document
  #
  # @return [Nokogiri::HTML::DocumentFragment]
  #     The presentation DOM with the glossary page rendered.
  #
  # @see
  #     https://github.com/puppetlabs/showoff/blob/3f43754c84f97be4284bb34f9bc7c42175d45226/lib/showoff.rb#L770-L810
  def self.generatePage!(doc)
      doc.search('.slide.glossary .content').each do |glossary|
        name = (glossary.attr('class').split - ['content', 'glossary']).first
        list = Nokogiri::XML::Node.new('ul', doc)
        list.add_class('glossary terms')
        seen = []

        doc.search('.callout.glossary').each do |item|
          target = (item.attr('class').split - ['callout', 'glossary']).first

          # if the name matches or if we didn't name it to begin with.
          next unless target == name

          # the definition can exist in multiple places, so de-dup it here
          term = item.attr('data-term')
          next if seen.include? term
          seen << term

          # excrutiatingly find the parent slide content and grab the ref
          # in a library less shitty, this would be something like
          # $(this).parent().siblings('.content').attr('ref')
          href = nil
          item.ancestors('.slide').first.traverse do |element|
            next if element['class'].nil?
            next unless element['class'].split.include? 'content'

            href = element.attr('ref').gsub('/', '_')
          end

          text   = item.attr('data-text')
          link   = item.attr('data-target')
          page   = glossary.attr('ref')
          anchor = "#{page}+#{link}"
          next if href.nil? or text.nil? or link.nil?

          entry = Nokogiri::XML::Node.new('li', doc)

          label = Nokogiri::XML::Node.new('a', doc)
          label.add_class('label')
          label.set_attribute('id', anchor)
          label.content = term

          link = Nokogiri::XML::Node.new('a', doc)
          label.add_class('return')
          link.set_attribute('href', "##{href}")
          link.content = '↩'

          entry.add_child(label)
          entry.add_child(Nokogiri::XML::Text.new(text, doc))
          entry.add_child(link)

          list.add_child(entry)
        end

        glossary.add_child(list)
      end

      # now fix all the links to point to the glossary page
      doc.search('a').each do |link|
        next if link['href'].nil?
        next unless link['href'].start_with? 'glossary://'

        href = link['href']
        href.slice!('glossary://')

        parts  = href.split('/')
        target = parts.pop
        name   = parts.pop # either the glossary name or nil

        classes = name.nil? ? ".slide.glossary" : ".slide.glossary.#{name}"
        href    = doc.at("#{classes} .content").attr('ref') rescue nil

        link['href'] = "##{href}+#{target}"
      end

      doc
  end

end
