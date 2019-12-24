class Showoff::Presentation
  require 'showoff/presentation/section'
  require 'showoff/presentation/slide'

  attr_reader :sections

  def initialize(options)
    @sections = Showoff::Config.sections.map do |name, files|
      Showoff::Presentation::Section.new(name, files)
    end
  end

  def render
    Showoff::State.reset([:slide_count, :section_major, :section_minor])
    @sections.map(&:render).join("\n")
  end

end
