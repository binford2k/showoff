require 'tilt'

class Showoff::Presentation::Slide
  attr_reader :options, :markdown, :classes

  def initialize(context, content)
    @markdown = content
    @template = "default"
    @classes  = []
    @options  = {}
    parseContext!(context)
  end

  # This is where the magic starts!
  def render
    # add the real slide rendering logic here
    Tilt[:markdown].new(nil, nil, @engine_options) { @markdown }.render
  end

  def parseContext!(context)
    return unless context
    return unless matches = context.match(/(\[(.*?)\])?(.*)/)

    if matches[2]
      matches[2].split(",").each do |element|
        key, val      = element.split("=")
        @options[key] = val
      end
    end

    if matches[3]
      @classes = matches[3].split
    end
  end

  # this is a terrible implementation!
  def name
    @markdown.split("\n").find {|line| line.match(/^#/) }
  end
end
