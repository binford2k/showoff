require 'tilt'
require 'tilt/erb'
require 'nokogiri'

class Showoff::Compiler
  require 'showoff/compiler/form'
  require 'showoff/compiler/variables'
  require 'showoff/compiler/fixups'
  require 'showoff/compiler/i18n'
  require 'showoff/compiler/notes'
  require 'showoff/compiler/glossary'
  require 'showoff/compiler/downloads'
  require 'showoff/compiler/table_of_contents'

  def initialize(options)
    @options = options
    @profile = profile
  end

  # Configures Tilt with the selected engine and options.
  #
  # Returns render options profile hash
  #
  # Source:
  #  https://github.com/puppetlabs/showoff/blob/3f43754c84f97be4284bb34f9bc7c42175d45226/lib/showoff_utils.rb#L671-L720
  # TODO: per slide profiles of render options
  def profile
    renderer = Showoff::Config.get('markdown')
    profile  = Showoff::Config.get(renderer)

    begin
      # Load markdown configuration
      case renderer
      when 'rdiscount'
        Tilt.prefer Tilt::RDiscountTemplate, "markdown"

      when 'maruku'
        Tilt.prefer Tilt::MarukuTemplate, "markdown"
        # Now check if we can go for latex mode
        require 'maruku'
        require 'maruku/ext/math'

        if profile[:use_tex]
          MaRuKu::Globals[:html_math_output_mathml] = false
          MaRuKu::Globals[:html_math_output_png]    = true
          MaRuKu::Globals[:html_math_engine]        = 'none'
          MaRuKu::Globals[:html_png_engine]         = 'blahtex'
          MaRuKu::Globals[:html_png_dir]            = profile[:png_dir]
          MaRuKu::Globals[:html_png_url]            = profile[:html_png_url]
        end

      when 'bluecloth'
        Tilt.prefer Tilt::BlueClothTemplate, "markdown"

      when 'kramdown'
        Tilt.prefer Tilt::KramdownTemplate, "markdown"

      when 'commonmarker', 'commonmark'
        Tilt.prefer Tilt::CommonMarkerTemplate, "markdown"

      when 'redcarpet', :default
        Tilt.prefer Tilt::RedcarpetTemplate, "markdown"

      else
        raise 'Unsupported markdown renderer'

      end
    rescue LoadError
      puts "ERROR: The #{renderer} markdown rendering engine does not appear to be installed correctly."
      exit 1
    end

    profile
  end

  # Compiles markdown and all Showoff extensions into the final HTML output and notes.
  #
  # @param content [String] markdown content.
  # @return [[String, Array<String>]] A tuple of (html content, array of notes contents)
  #
  # @todo I think the update_image_paths() malarky is redundant. Verify that.
  def render(content)
    Variables::interpolate!(content)
    I18n.selectLanguage!(content)

    html = Tilt[:markdown].new(nil, nil, @profile) { content }.render
    doc  = Nokogiri::HTML::DocumentFragment.parse(html)

    Form.render!(doc, @options)
    Fixups.updateClasses!(doc)
    Fixups.updateLinks!(doc)
    Fixups.updateSyntaxHighlighting!(doc)
    Fixups.updateCommandlineBlocks!(doc)
    Fixups.updateImagePaths!(doc, @options)
    Glossary.render!(doc)
    Downloads.scanForFiles!(doc, @options)

    # This call must be last in the chain because it separates notes from the
    # content and returns them separately. If it's not last, then the notes
    # won't have all the compilation steps applied to them.
    #
    # must pass in extra context because this will render markdown itself
    Notes.render!(doc, @profile, @options)
  end

end
