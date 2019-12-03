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
    @sections.map(&:render).join("\n")
  end

end
