class Showoff::Presentation::Section
  attr_reader :slides, :name

  def initialize(name, files)
    @name   = name
    @slides = []
    files.each { |filename| loadSlides(filename) }

    # merged output means that we just want to generate *everything*. This is used by internal,
    # methods such as content validation, where we want all content represented.
    # https://github.com/puppetlabs/showoff/blob/220d6eef4c5942eda625dd6edc5370c7490eced7/lib/showoff.rb#L429-L453
    unless Showoff::State.get(:merged)
      if Showoff::State.get(:supplemental)
        # if we're looking for supplemental material, only include the content we want
        @slides.select! {|slide| slide.classes.include? 'supplemental' }
        @slides.select! {|slide| slide.classes.include? Showoff::State.get(:supplemental) }
      else
        # otherwise just skip all supplemental material completely
        @slides.reject! {|slide| slide.classes.include? 'supplemental' }
      end

      case Showoff::State.get(:format)
      when 'web'
        @slides.reject! {|slide| slide.classes.include? 'toc' }
        @slides.reject! {|slide| slide.classes.include? 'printonly' }
      when 'print', 'supplemental'
        @slides.reject! {|slide| slide.classes.include? 'noprint' }
      end
    end

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

    content = File.read(File.join(Showoff::Locale.contentPath, filename))

    # if there are no !SLIDE markers, then make every H1 define a new slide
    unless content =~ /^\<?!SLIDE/m
      content = content.gsub(/^# /m, "<!SLIDE>\n# ")
    end

    slides = content.split(/^<?!SLIDE\s?([^>]*)>?/)
    slides.shift # has an extra empty string because the regex matches the entire source string.

    # this is a counter keeping track of how many slides came from the file.
    # It kicks in at 2 because at this point, slides are a tuple of (options, content)
    seq = slides.size > 2 ? 1 : nil

    # iterate each slide tuple and add slide objects to the array
    slides.each_slice(2) do |data|
      options, content = data
      @slides << Showoff::Presentation::Slide.new(options, content, :section => @name, :name => filename, :seq => seq)
      seq +=1 if seq
    end

  end

end
