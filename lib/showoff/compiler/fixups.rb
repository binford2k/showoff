# adds misc fixup methods to the compiler
class Showoff::Compiler::Fixups

    # Find any <p> or <img> tags with classes defined via the prefixed dot syntax.
    # Remove .break and .comment paragraphs and apply classes/alt to the rest.
    #
    # @param doc [Nokogiri::HTML::DocumentFragment]
    #     The slide document
    # @return [Nokogiri::HTML::DocumentFragment]
    #     The document with classes applied.
    def self.updateClasses(doc)
      doc.search('p').select {|p| p.text.start_with? '.'}.each do |p|
        # The first string of plain text in the paragraph
        node = p.children.first
        classes, sep, text = node.content.partition(' ')
        classes = classes.split('.')
        classes.shift

        if ['break', 'comment'].include? classes.first
          p.remove
        else
          p.add_class(classes.join(' '))
          node.content = text
        end
      end

      doc.search('img').select {|img| img.attr('alt').start_with? '.'}.each do |img|
        classes, sep, text = img.attr('alt').partition(' ')
        classes = classes.split('.')
        classes.shift

        img.add_class(classes.join(' '))
        img.set_attribute('alt', text)
      end

      doc
    end

    # Ensure that all links open in a new window. Perhaps move some of this to glossary.rb
    def self.updateLinks(doc)
      doc.search('a').each do |link|
        next unless link['href']
        next if link['href'].start_with? '#'
        # Add a target so we open all external links from notes in a new window
        link.set_attribute('target', '_blank')
      end

      doc
    end
end
