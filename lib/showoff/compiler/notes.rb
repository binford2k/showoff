# adds presenter notes processing to the compiler
class Showoff::Compiler::Notes

  # Generate the presenter notes sections, including personal notes
  #
  # @param doc [Nokogiri::HTML::DocumentFragment]
  #     The slide document
  #
  # @param profile [String]
  #     The markdown engine profile to use when rendering
  #
  # @param options [Hash] Options used for rendering any embedded markdown
  # @option options [String] :name The markdown slide name
  # @option options [String] :seq The sequence number for multiple slides in one file
  #
  # @return [Nokogiri::HTML::DocumentFragment]
  #     The slide DOM with all notes sections rendered.
  #
  # @see
  #     https://github.com/puppetlabs/showoff/blob/3f43754c84f97be4284bb34f9bc7c42175d45226/lib/showoff.rb#L616-L716
  # @note
  #     A ton of the functionality in the original method got refactored to its logical location
  def self.render(doc, profile, options = {})
    # Turn tags into classed divs.
    doc.search('p').select {|p| p.text.start_with?('~~~SECTION:') }.each do |p|
      klass = p.text.match(/~~~SECTION:([^~]*)~~~/)[1]

      # Don't bother creating this if we don't want to use it
      next unless Showoff::Config.includeSection?(klass)

      notes = Nokogiri::XML::Node.new('div', doc).add_class("notes-section #{klass}")
      nodes = []
      iter = p.next_sibling
      until iter.text == '~~~ENDSECTION~~~' do
        nodes << iter
        iter = iter.next_sibling

        # if the author forgot the closing tag, let's not crash, eh?
        break unless iter
      end
      iter.remove if iter # remove the extraneous closing ~~~ENDSECTION~~~ tag

      # We need to collect the list before moving or the iteration crashes since the iterator no longer has a sibling
      nodes.each {|n| n.parent = notes }

      p.replace(notes)
    end

    filename = [
      File.join(Showoff::Config.root, '_notes', "#{options[:name]}.#{options[:seq]}.md"),
      File.join(Showoff::Config.root, '_notes', "#{options[:name]}.md"),
    ].find {|path| File.file?(path) }

    if filename and Showoff::Config.includeSection?('notes')
      # Make sure we've got a notes div to hang personal notes from
      doc.add_child '<div class="notes-section notes"></div>' if doc.search('div.notes-section.notes').empty?
      doc.search('div.notes-section.notes').each do |section|
        text = Tilt[:markdown].new(nil, nil, options[:profile]) { File.read(filename) }.render
        frag = "<div class=\"personal\"><h1>presenter.notes.personal}</h1>#{text}</div>" # @todo add back i18n #{I18n.t('presenter.notes.personal')}
        section.prepend_child(frag)
      end
    end

    doc
  end

end
