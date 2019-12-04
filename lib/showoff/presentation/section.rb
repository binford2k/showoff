class Showoff::Presentation::Section
  attr_reader :slides, :name

  def initialize(name, files)
    @name   = name
    @slides = files.map { |filename| loadSlides(filename) }.flatten
  end

  def render
    @slides.map(&:render).join("\n")
  end

  # Gets the raw file content from disk and partitions it by slide markers into
  # raw content for each slide.
  #
  # Returns an array of strings
  #
  # Source:
  #  https://github.com/puppetlabs/showoff/blob/3f43754c84f97be4284bb34f9bc7c42175d45226/lib/showoff.rb#L396-L414
  def loadSlides(filename)
    content = File.read(File.join(Showoff::Config.root, filename))

    # if there are no !SLIDE markers, then make every H1 define a new slide
    unless content =~ /^\<?!SLIDE/m
      content = content.gsub(/^# /m, "<!SLIDE>\n# ")
    end

    output = []
    until content.empty?
      # $1 is the slide marker context
      content, marker, slide = content.rpartition(/^<?!SLIDE\s?([^>]*)>?/)
      output.unshift Showoff::Presentation::Slide.new($1, slide)
    end

    output
  end

end
