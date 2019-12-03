require 'tilt'

class Showoff::Presentation::Slide
  attr_reader :section, :markdown

  def initialize(section, content)
    @section  = section
    @markdown = content
  end

  # This is where the magic starts!
  def render
    # add the real slide rendering logic here
    Tilt[:markdown].new(nil, nil, @engine_options) { @markdown }.render
  end

  # this is a terrible implementation!
  def name
    @markdown.split("\n").find {|line| line.match(/^#/) }
  end
end
