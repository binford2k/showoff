class Showoff::Presentation::Section
  attr_reader :slides, :name

  def initialize(name, files)
    @name = name
    @slides = files.map do |filename|
      # Files might define multiple slides
      getSlides(filename).map do |content|
        Showoff::Presentation::Slide.new(name, content)
      end
    end
    @slides.flatten!
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
  def getSlides(filename)
    content = File.read(File.join(Showoff::Config.root, filename))

    # if there are no !SLIDE markers, then make every H1 define a new slide
    unless content =~ /^\<?!SLIDE/m
      content = content.gsub(/^# /m, "<!SLIDE>\n# ")
    end

    output = []
    until content.empty?
      content, marker, slide = content.rpartition(/^<?!SLIDE(.*)>?/)
      output.unshift marker+slide
    end

    output
  end

end
