require 'commandline_parser'

# adds misc fixup methods to the compiler
class Showoff::Compiler::Fixups

    # Find any <p> or <img> tags with classes defined via the prefixed dot syntax.
    # Remove .break and .comment paragraphs and apply classes/alt to the rest.
    #
    # @param doc [Nokogiri::HTML::DocumentFragment]
    #     The slide document
    # @return [Nokogiri::HTML::DocumentFragment]
    #     The document with classes applied.
    def self.updateClasses!(doc)
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
    def self.updateLinks!(doc)
      doc.search('a').each do |link|
        next unless link['href']
        next if link['href'].start_with? '#'
        next if link['href'].start_with? 'glossary://'
        # Add a target so we open all external links from notes in a new window
        link.set_attribute('target', '_blank')
      end

      doc
    end

    # This munges code blocks to ensure the proper syntax highlighting
    # @see
    #     https://github.com/puppetlabs/showoff/blob/3f43754c84f97be4284bb34f9bc7c42175d45226/lib/showoff.rb#L1105-L1133
    def self.updateSyntaxHighlighting!(doc)
      doc.search('pre').each do |pre|
        pre.search('code').each do |code|
          out  = code.text
          lang = code.get_attribute('class')

          # Skip this if we've got an empty code block
          next if out.empty?

          # catch fenced code blocks from commonmarker
          if (lang and lang.start_with? 'language-' )
            pre.set_attribute('class', 'highlight')
            # turn the colon separated name back into classes
            code.set_attribute('class', lang.gsub(':', ' '))

          # or we've started a code block with a Showoff language tag
          elsif out.strip[0, 3] == '@@@'
            lines = out.split("\n")
            lang  = lines.shift.gsub('@@@', '').strip
            pre.set_attribute('class', 'highlight')
            code.set_attribute('class', 'language-' + lang.downcase) if !lang.empty?
            code.content = lines.join("\n")
          end

        end
      end

      doc
    end

    # This munges commandline code blocks for the proper classing
    # @see
    #     https://github.com/puppetlabs/showoff/blob/3f43754c84f97be4284bb34f9bc7c42175d45226/lib/showoff.rb#L1107
    #     https://github.com/puppetlabs/showoff/blob/3f43754c84f97be4284bb34f9bc7c42175d45226/lib/showoff.rb#L1135-L1163
    def self.updateCommandlineBlocks!(doc)
      parser = CommandlineParser.new
      doc.search('.commandline > pre > code').each do |code|
        out = code.text
        code.content = ''
        tree = parser.parse(out)
        transform = Parslet::Transform.new do
          rule(:prompt => simple(:prompt), :input => simple(:input), :output => simple(:output)) do
            command = Nokogiri::XML::Node.new('code', doc)
            command.set_attribute('class', 'command')
            command.content = "#{prompt} #{input}"
            code << command

            # Add newline after the input so that users can
            # advance faster than the typewriter effect
            # and still keep inputs on separate lines.
            code << "\n"

            unless output.to_s.empty?

              result = Nokogiri::XML::Node.new('code', doc)
              result.set_attribute('class', 'result')
              result.content = output
              code << result
            end
          end
        end
        transform.apply(tree)
      end

      doc
    end

    def self.updateImagePaths!(doc, options={})
      doc.search('img').each do |img|
        slide_dir = File.dirname(options[:name])

        # does the image path start from the preso root?
        unless img[:src].start_with? '/'
          # clean up the path and remove some of the relative nonsense
          img[:src] = Pathname.new(File.join(slide_dir, img[:src])).cleanpath.to_path
        end
      end
    end
end
