class Showoff::Presentation
  require 'showoff/presentation/section'
  require 'showoff/presentation/slide'
  require 'showoff/compiler'
  require 'keymap'

  attr_reader :sections

  def initialize(options)
    @options  = options
    @sections = Showoff::Config.sections.map do |name, files|
      Showoff::Presentation::Section.new(name, files)
    end

    # weird magic variables the presentation expects
    @baseurl   = nil # this doesn't appear to have ever been used
    @title     = Showoff::Config.get('name')    || I18n.t('name')
    @favicon   = Showoff::Config.get('favicon') || 'favicon.ico'
    @feedback  = Showoff::Config.get('feedback') # note: the params check is obsolete
    @pause_msg = Showoff::Config.get('pause_msg')
    @language  = Showoff::Locale.translations
    @edit      = Showoff::Config.get('edit') if options[:review]

    # invert the logic to maintain backwards compatibility of interactivity on by default
    @interactive = ! options[:standalone]

    # Load up the default keymap, then merge in any customizations
    keymapfile   = File.expand_path(File.join('~', '.showoff', 'keymap.json'))
    @keymap      = Keymap.default
    @keymap.merge! JSON.parse(File.read(keymapfile)) rescue {}

    # map keys to the labels we're using
    @keycode_dictionary   = Keymap.keycodeDictionary
    @keycode_shifted_keys = Keymap.shiftedKeyDictionary

    @highlightStyle = Showoff::Config.get('highlight') || 'default'

    if Showoff::State.get(:supplemental)
      @wrapper_classes = ['supplemental']
    end
  end

  def compile
    Showoff::State.reset([:slide_count, :section_major, :section_minor])

    # @todo For now, we reparse the html so that we can generate content via slide
    #       templates. This adds a bit of extra time, but not too much. Perhaps
    #       we'll change that at some point.
    html = @sections.map(&:render).join("\n")
    doc  = Nokogiri::HTML::DocumentFragment.parse(html)

    Showoff::Compiler::TableOfContents.generate!(doc)
    Showoff::Compiler::Glossary.generatePage!(doc)

    doc
  end

  # The index page does not contain content; just a placeholder div that's
  # dynamically loaded after the page is displayed. This increases perceived
  # responsiveness.
  def index
    ERB.new(File.read(File.join(Showoff::GEMROOT, 'views','index.erb')), nil, '-').result(binding)
  end

  def slides
    compile.to_html
  end

  def static
    # This singleton guard removes ordering coupling between assets() & static()
    @doc  ||= compile
    @slides = @doc.to_html

    # All static snapshots should be non-interactive by definition
    @interactive = false

    case Showoff::State.get(:format)
    when 'web'
      template = 'index.erb'
    when 'print', 'supplemental', 'pdf'
      template = 'onepage.erb'
    end

    ERB.new(File.read(File.join(Showoff::GEMROOT, 'views', template)), nil, '-').result(binding)
  end

  # Generates a list of all image/font/etc files used by the presentation. This
  # will only identify the sources of <img> tags and files referenced by the
  # CSS url() function.
  #
  # @see
  #     https://github.com/puppetlabs/showoff/blob/220d6eef4c5942eda625dd6edc5370c7490eced7/lib/showoff.rb#L1509-L1573
  # @returns [Array]
  #     List of assets, such as images or fonts, used by the presentation.
  def assets
    # This singleton guard removes ordering coupling between assets() & static()
    @doc ||= compile

    # matches url(<path>) and returns the path as a capture group
    urlsrc = /url\([\"\']?(.*?)(?:[#\?].*)?[\"\']?\)/

    # get all image and url() sources
    files = @doc.search('img').map {|img| img[:src] }
    @doc.search('*').each do |node|
      next unless node[:style]
      next unless matches = node[:style].match(urlsrc)
      files << matches[1]
    end

    # add in images from css files too
    css_files.each do |css_path|
      data = File.read(File.join(Showoff::Config.root, css_path))

      # @todo: This isn't perfect. It will match commented out styles. But its
      # worst case behavior is displaying a warning message, so that's ok for now.
      data.scan(urlsrc).flatten.each do |path|
        # resolve relative paths in the stylesheet
        path = File.join(File.dirname(css_path), path) unless path.start_with? '/'
        files << path
      end
    end

    # also all user-defined styles and javascript files
    files.concat css_files
    files.concat js_files
    files.uniq
  end

  def erb(template)
    ERB.new(File.read(File.join(Showoff::GEMROOT, 'views', "#{template}.erb")), nil, '-').result(binding)
  end

  def css_files
    base  = Dir.glob("#{Showoff::Config.root}/*.css").map { |path| File.basename(path) }
    extra = Array(Showoff::Config.get('styles'))
    base + extra
  end

  def js_files
    base  = Dir.glob("#{Showoff::Config.root}/*.js").map { |path| File.basename(path) }
    extra = Array(Showoff::Config.get('scripts'))
    base + extra
  end

  # return a list of keys associated with a given action in the keymap
  def mapped_keys(action, klass='key')
    list = @keymap.select { |key,value| value == action }.keys

    if klass
      list.map { |val| "<span class=\"#{klass}\">#{val}</span>" }.join
    else
      list.join ', '
    end
  end




  # @todo: backwards compatibility shim
  def user_translations
    Showoff::Locale.userTranslations
  end

  # @todo: backwards compatibility shim
  def language_names
    Showoff::Locale.contentLanguages
  end


  # @todo: this should be part of the server. Move there with the least disruption.
  def master_presenter?
    false
  end

  # @todo: this should be part of the server. Move there with the least disruption.
  def valid_presenter_cookie?
    false
  end


end
