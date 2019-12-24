# adds file download link processing
class Showoff::Compiler::Downloads

  # Scan for file download links and move them to the state storage.
  #
  # @param doc [Nokogiri::HTML::DocumentFragment]
  #     The slide document
  #
  # @return [Nokogiri::HTML::DocumentFragment]
  #     The slide DOM with download links removed.
  #
  # @todo Should .download change meaning to 'make available on this slide'?
  #
  # @see
  #     https://github.com/puppetlabs/showoff/blob/3f43754c84f97be4284bb34f9bc7c42175d45226/lib/showoff.rb#L1056-L1073
  def self.scanForFiles(doc, options)
    current = Showoff::State.get(:slide_count)
    doc.search('p.download').each do |container|
      links = container.text.gsub(/^\.download ?/, '')
      links.split("\n").each do |line|
        file, modifier = line.split
        modifier ||= 'next' # @todo Is this still the proper default?

        case modifier
        when 'a', 'all', 'always', 'now'
          self.pushFile(0, current, options[:name], file)
        when 'p', 'prev', 'previous'
          self.pushFile(current-1, current, options[:name], file)
        when 'c', 'curr', 'current'
          self.pushFile(current, current, options[:name], file)
        when 'n', 'next'
          self.pushFile(current+1, current, options[:name], file)
        end
      end

      container.remove
    end

    doc
  end


# Convention that index 0 represents files that are always available and every
# other index represents files whose visibility will be triggered on that slide.
#
#   [
#     {
#       :enabled => false,
#       :slides  => [
#                     {:slidenum => num, :source => name, :file => file},
#                     {:slidenum => num, :source => name, :file => file},
#                   ],
#     },
#     {
#       :enabled => false,
#       :slides  => [
#                     {:slidenum => num, :source => name, :file => file},
#                     {:slidenum => num, :source => name, :file => file},
#                   ],
#     },
#   ]


  def self.pushFile(index, current, source, file)
    record = Showoff::State.getAtIndex(:downloads, index) || {}
    record[:enabled] ||= false
    record[:slides]  ||= []
    record[:slides] << {:slidenum => current, :source => source, :file => file}

    Showoff::State.setAtIndex(:downloads, index, record)
  end

  def self.enableFiles(index)
    record = Showoff::State.getAtIndex(:downloads, index)

    record[:enabled] = true
    Showoff::State.setAtIndex(:downloads, index, record)
  end

  def self.getFiles(index)
    record = Showoff::State.getAtIndex(:downloads, index)
    record[:slides] if record[:enabled]
  end

end
