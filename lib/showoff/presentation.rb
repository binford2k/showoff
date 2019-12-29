class Showoff::Presentation
  require 'showoff/presentation/section'
  require 'showoff/presentation/slide'
  require 'showoff/compiler'

  attr_reader :sections

  def initialize(options)
    @sections = Showoff::Config.sections.map do |name, files|
      Showoff::Presentation::Section.new(name, files)
    end
  end

  def render
    Showoff::State.reset([:slide_count, :section_major, :section_minor])

    # @todo For now, we reparse the html so that we can generate content via
    #       templates. This adds a bit of extra time, but not too much. Perhaps
    #       we'll change that at some point.
    html = @sections.map(&:render).join("\n")
    doc  = Nokogiri::HTML::DocumentFragment.parse(html)

    Showoff::Compiler::TableOfContents.generate!(doc)
    Showoff::Compiler::Glossary.generatePage!(doc)

    puts doc.to_html
  end



end
