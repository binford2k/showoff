class Showoff::Presentation::Section
  attr_reader :slides, :name

  def initialize(name, files)
    @name          = name
    @section_title = name
    @slides        = []
    files.each { |filename| loadSlides(filename) }
  end

  def render
    @slides.map(&:render).join("\n")
  end

  # Gets the raw file content from disk and partitions it by slide markers into
  # content for each slide.
  #
  # Returns an array of Slide objects
  #
  # Source:
  #  https://github.com/puppetlabs/showoff/blob/3f43754c84f97be4284bb34f9bc7c42175d45226/lib/showoff.rb#L396-L414
  def loadSlides(filename)
    return unless filename.end_with? '.md'

    content = File.read(File.join(Showoff::Config.root, filename))

    # if there are no !SLIDE markers, then make every H1 define a new slide
    unless content =~ /^\<?!SLIDE/m
      content = content.gsub(/^# /m, "<!SLIDE>\n# ")
    end

    slides = content.split(/^<?!SLIDE\s?([^>]*)>?/)
    slides.shift # has an extra empty string because the regex matches the entire source string.

    seq = slides.size > 2 ? 1 : nil

    slides.each_slice(2) do |data|
      slide = Showoff::Presentation::Slide.new(data[0], data[1], :section => @name, :name => filename, :seq => seq)

      # parsed from subsection slides and carried forward across slides until a new subsection title comes up
      # This should be replaced with section titles/names in showoff.json hashes
      @section_title = slide.updateSectionTitle(@section_title)

      @slides << slide
      seq +=1 if seq
    end

  end

end
