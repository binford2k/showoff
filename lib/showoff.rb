require 'rubygems'
require 'sinatra/base'
require 'json'
require 'nokogiri'
require 'fileutils'
require 'pathname'
require 'logger'
require 'htmlentities'
require 'sinatra-websocket'
require 'tempfile'

require 'i18n'
require 'i18n/backend/fallbacks'
require 'rack'
require 'rack/contrib'
require 'iso-639'

here = File.expand_path(File.dirname(__FILE__))
require "#{here}/showoff_utils"
require "#{here}/commandline_parser"
require "#{here}/keymap"

begin
  require 'pdfkit'
rescue LoadError
  # nop
end

require 'tilt'

class ShowOff < Sinatra::Application

  attr_reader :cached_image_size

  # Set up application variables

  set :views, File.dirname(__FILE__) + '/../views'
  set :public_folder, File.dirname(__FILE__) + '/../public'

  set :statsdir, "stats"
  set :viewstats, "viewstats.json"
  set :feedback, "feedback.json"
  set :forms, "forms.json"

  set :server, 'thin'
  set :sockets, []
  set :presenters, []

  set :verbose, false
  set :review,  false
  set :execute, false
  set :nocache, false

  set :pres_dir, '.'
  set :pres_file, 'showoff.json'
  set :page_size, "Letter"
  set :pres_template, nil
  set :showoff_config, {}
  set :encoding, nil
  set :url, nil

  # automatically select the translation based on the user's configured browser language
  use Rack::Locale

  configure do
    I18n::Backend::Simple.send(:include, I18n::Backend::Fallbacks)
    I18n.load_path += Dir[File.join(settings.root, '..', 'locales', '*.yml')]
    I18n.backend.load_translations
    I18n.enforce_available_locales = false
  end

  def initialize(app=nil)
    super(app)
    @logger = Logger.new(STDERR)
    @logger.formatter = proc { |severity,datetime,progname,msg| "#{progname} #{msg}\n" }
    @logger.level = settings.verbose ? Logger::DEBUG : Logger::WARN

    @review  = settings.review
    @execute = settings.execute

    settings.pres_dir ||= Dir.pwd
    @root_path = "."

    # Load up the default keymap, then merge in any customizations
    keymapfile   = File.expand_path(File.join('~', '.showoff', 'keymap.json')) rescue nil
    @keymap      = Keymap.default
    @keymap.merge! JSON.parse(File.read(keymapfile)) rescue {}

    # map keys to the labels we're using
    @keycode_dictionary   = Keymap.keycodeDictionary
    @keycode_shifted_keys = Keymap.shiftedKeyDictionary

    settings.pres_dir = File.expand_path(settings.pres_dir)
    if (settings.pres_file and settings.pres_file != 'showoff.json')
      ShowOffUtils.presentation_config_file = settings.pres_file
    end

    # Load configuration for page size and template from the
    # configuration JSON file
    if File.exist?(ShowOffUtils.presentation_config_file)
      showoff_json = JSON.parse(File.read(ShowOffUtils.presentation_config_file))
      settings.showoff_config = showoff_json

      # Set options for encoding, template and page size
      settings.encoding      = showoff_json["encoding"]  || 'UTF-8'
      settings.page_size     = showoff_json["page-size"] || "Letter"
      settings.pres_template = showoff_json["templates"]
    end

    # if no sections are provided, we'll just start from cwd
    settings.showoff_config['sections'] ||= ['.']

    # code execution timeout
    settings.showoff_config['timeout'] ||= 15

    # If favicon in presentation root, use it by default
    if File.exist? 'favicon.ico'
      settings.showoff_config['favicon'] ||= 'file/favicon.ico'
    end

    # default protection levels
    if settings.showoff_config.has_key? 'password'
      settings.showoff_config['protected'] ||= ["presenter", "onepage", "print"]
    else
      settings.showoff_config['protected'] ||= Array.new
    end

    if settings.showoff_config.has_key? 'key'
      settings.showoff_config['locked'] ||= ["slides"]
    else
      settings.showoff_config['locked'] ||= Array.new
    end

    # default code parsers (for executable code blocks)
    settings.showoff_config['parsers'] ||= {}
    settings.showoff_config['parsers']['perl']   ||= 'perl'
    settings.showoff_config['parsers']['puppet'] ||= 'puppet apply --color=false'
    settings.showoff_config['parsers']['python'] ||= 'python'
    settings.showoff_config['parsers']['ruby']   ||= 'ruby'
    settings.showoff_config['parsers']['shell']  ||= 'sh'

    # default code validators
    settings.showoff_config['validators'] ||= {}
    settings.showoff_config['validators']['perl']   ||= 'perl -cw'
    settings.showoff_config['validators']['puppet'] ||= 'puppet parser validate'
    settings.showoff_config['validators']['python'] ||= 'python -m py_compile'
    settings.showoff_config['validators']['ruby']   ||= 'ruby -c'
    settings.showoff_config['validators']['shell']  ||= 'sh -n'

    # highlightjs syntax style
    @highlightStyle = settings.showoff_config['highlight'] || 'default'

    # variables used for building section numbering and title
    @slide_count   = 0
    @section_major = 0
    @section_minor = 0
    @section_title = settings.showoff_config['name'] rescue I18n.t('name')
    @@slide_titles  = [] # a list of generated slide names, used for cross references later.

    @logger.debug settings.pres_template

    @cached_image_size = {}
    @logger.debug settings.pres_dir
    @pres_name = settings.pres_dir.split('/').pop
    require_ruby_files

    # invert the logic to maintain backwards compatibility of interactivity on by default
    @interactive = ! settings.standalone rescue false

    # Create stats directory
    FileUtils.mkdir settings.statsdir unless File.directory? settings.statsdir if @interactive

    # Page view time accumulator. Tracks how often slides are viewed by the audience
    begin
      @@counter = JSON.parse(File.read("#{settings.statsdir}/#{settings.viewstats}"))

      # TODO: remove this logic 4/15/2017: port old format stats
      unless @@counter.has_key? 'user_agents'
        @@counter['pageviews'] = @@counter
      end

      @@counter['current']     ||= {}
      @@counter['pageviews']   ||= {}
      @@counter['user_agents'] ||= {}
    rescue
      @@counter = { 'user_agents' => {}, 'pageviews' => {}, 'current' => {} }
    end

    # keeps track of form responses. In memory to avoid concurrence issues.
    begin
      @@forms = JSON.parse(File.read("#{settings.statsdir}/#{settings.forms}"))
    rescue
      @@forms = Hash.new
    end

    @@downloads = Hash.new # Track downloadable files
    @@cookie    = nil      # presenter cookie. Identifies the presenter for control messages
    @@master    = nil      # this holds the @client_id of the master presenter, for the cases in which multiple presenters are loaded
    @@current   = Hash.new # The current slide that the presenter is viewing
    @@cache     = Hash.new # Cache slide content for subsequent hits
    @@activity  = []       # keep track of completion for activity slides

    if @interactive
      # flush stats to disk periodically
      Thread.new do
        loop do
          sleep 30
          ShowOff.flush
        end
      end
    end

    # Initialize Markdown Configuration
    MarkdownConfig::setup(settings.pres_dir)

    # Process renderer config options
    @engine_options = ShowOffUtils.showoff_renderer_options(settings.pres_dir)

  end
  # save stats to disk
  def self.flush
    begin
      if defined?(@@counter) and not @@counter.empty?
        File.open("#{settings.statsdir}/#{settings.viewstats}", 'w') do |f|
          if settings.verbose then
            f.write(JSON.pretty_generate(@@counter))
          else
            f.write(@@counter.to_json)
          end
        end
      end

      if defined?(@@forms) and not @@forms.empty?
        File.open("#{settings.statsdir}/#{settings.forms}", 'w') do |f|
          if settings.verbose then
            f.write(JSON.pretty_generate(@@forms))
          else
            f.write(@@forms.to_json)
          end
        end
      end
    rescue Errno::ENOENT => e
    end
  end

  def self.pres_dir_current
    opt = {:pres_dir => Dir.pwd}
    ShowOff.set opt
  end

  def require_ruby_files
    Dir.glob("#{settings.pres_dir}/*.rb").map { |path| require path }
  end

  helpers do
    def css_files
      base  = Dir.glob("#{settings.pres_dir}/*.css").map { |path| File.basename(path) }
      extra = Array(settings.showoff_config['styles'])
      base + extra
    end

    def js_files
      base  = Dir.glob("#{settings.pres_dir}/*.js").map { |path| File.basename(path) }
      extra = Array(settings.showoff_config['scripts'])
      base + extra
    end

    def preshow_files
      files = Dir.glob("#{settings.pres_dir}/_preshow/*")
      files.reject! { |path| ['.txt', '.md'].include? File.extname(path) }
      files.map { |path| File.basename(path) }.to_json
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

    # This is just a unified lookup method that takes a full locale name
    # and then resolves it to an available version of the name
    def with_locale(locale)
      locale = locale.to_s
      until (locale.empty?) do
        result = yield(locale)
        return result unless result.nil?

        # if not found, chop off a section and try again
        locale = locale.rpartition(/[-_]/).first
      end
    end

    # turns a locale code into a string name
    def get_language_name(locale)
      with_locale(locale) do |str|
        result = ISO_639.find(str)
        result[3] unless result.nil?
      end
    end

    # This function returns the directory containing translated *content*, defaulting
    # to cwd. This works similarly to I18n fallback, but we cannot reuse that as it's
    # a different translation mechanism.
    def get_locale_dir(prefix, locale)
      return '.' if locale == 'disable'

      with_locale(locale) do |str|
        path = "#{prefix}/#{str}"
        return path if File.directory?(path)
      end || '.'
    end

    # return a hash of all language codes available and the long name description of each
    def language_names
      strings = JSON.parse(File.read('locales/strings.json')) rescue {}
      locales = Dir.glob('locales/*')
                   .select {|f| File.directory?(f) }
                   .map    {|f| File.basename(f)   }

      (strings.keys + locales).inject({}) do |memo, locale|
        memo.update(locale => get_language_name(locale))
      end
    end

    # returns the minimized canonical version of the current selected content locale
    # it assumes that if the user has specified a locale, that it's already minimized
    # note: if the locale doesn't exist on disk, it will just default to no translation
    def locale(user_locale)
      if [nil, '', 'auto'].include? user_locale
        languages = I18n.available_locales
        I18n.fallbacks[I18n.locale].select { |f| languages.include? f }.first
      else
        user_locale
      end
    end

    # returns a hash of all translations for the current language. This is used
    # for the javascript half of the translations
    def get_translations
      languages = I18n.backend.send(:translations)
      fallback  = I18n.fallbacks[I18n.locale].select { |f| languages.keys.include? f }.first
      languages[fallback]
    end

    # Finds the language key from strings.json and returns the strings hash. This is
    # used for user translations in the presentation, e.g. SVG translations.
    def user_translations
      return {} unless File.file? 'locales/strings.json'
      strings = JSON.parse(File.read('locales/strings.json')) rescue {}

      with_locale(@locale) do |key|
        return strings[key] if strings.include? key
      end
      {}
    end

    # todo: move more behavior into this class
    class Slide
      attr_reader :classes, :text, :tpl, :bg
      def initialize( context = "")

        @tpl = "default"
        @classes = []

        # Parse the context string for options and content classes
        if context and context.match(/(\[(.*?)\])?(.*)/)
          options = ShowOffUtils.parse_options($2)
          @tpl = options["tpl"] if options["tpl"]
          @bg = options["bg"] if options["bg"]
          @classes += $3.strip.chomp('>').split if $3
        end

        @text = ""
      end
      def <<(s)
        @text << s
        @text << "\n"
      end
      def empty?
        @text.strip == ""
      end
    end

    def process_markdown(name, section, content, opts={:static=>false, :pdf=>false, :print=>false, :toc=>false, :supplemental=>nil, :section=>nil, :merged=>false})
      if settings.encoding and content.respond_to?(:force_encoding)
        content.force_encoding(settings.encoding)
      end
      @logger.debug "renderer: #{Tilt[:markdown].name}"
      @logger.debug "render options: #{@engine_options.inspect}"

      # if there are no !SLIDE markers, then make every H1 define a new slide
      unless content =~ /^\<?!SLIDE/m
        content = content.gsub(/^# /m, "<!SLIDE>\n# ")
      end

      # todo: unit test
      lines = content.split("\n")
      @logger.debug "#{name}: #{lines.length} lines"
      slides = []
      slides << (slide = Slide.new)
      until lines.empty?
        line = lines.shift
        if line =~ /^<?!SLIDE(.*)>?/
          ctx = $1 ? $1.strip : $1
          slides << (slide = Slide.new(ctx))
        else
          slide << line
        end
      end

      slides.delete_if {|slide| slide.empty? and not slide.bg }

      final = ''
      if slides.size > 1
        seq = 1
      end
      slides.each do |slide|
        # update section counters before we reject slides so the numbering is consistent
        if slide.classes.include? 'subsection'
          @section_major += 1
          @section_minor = 0
        end

        # merged output means that we just want to generate *everything*. This is used by internal,
        # methods such as content validation, where we want all content represented.
        unless opts[:merged]
          if opts[:supplemental]
            # if we're looking for supplemental material, only include the content we want
            next unless slide.classes.include? 'supplemental'
            next unless slide.classes.include? opts[:supplemental]
          else
            # otherwise just skip all supplemental material completely
            next if slide.classes.include? 'supplemental'
          end

          unless opts[:toc]
            # just drop the slide if we're not generating a table of contents
            next if slide.classes.include? 'toc'
          end

          if opts[:print]
            # drop all slides not intended for the print version
            next if slide.classes.include? 'noprint'
          else
            # drop slides that are intended for the print version only
            next if slide.classes.include? 'printonly'
          end
        end

        @slide_count += 1
        content_classes = slide.classes

        # extract transition, defaulting to none
        transition = 'none'
        content_classes.delete_if { |x| x =~ /^transition=(.+)/ && transition = $1 }
        # extract id, defaulting to none
        id = nil
        content_classes.delete_if { |x| x =~ /^#([\w-]+)/ && id = $1 }
        id = name.dup unless id
        id.gsub!(/[^-A-Za-z0-9_]/, '_') # valid HTML id characters
        id << seq.to_s if seq

        @logger.debug "id: #{id}" if id
        @logger.debug "classes: #{content_classes.inspect}"
        @logger.debug "transition: #{transition}"
        @logger.debug "tpl: #{slide.tpl} " if slide.tpl
        @logger.debug "bg: #{slide.bg}" if slide.bg


        template = "~~~CONTENT~~~"
        # Template handling
        if settings.pres_template
          # We allow specifying a new template even when default is
          # not given.
          if settings.pres_template.include?(slide.tpl) and
              File.exist?(settings.pres_template[slide.tpl])
            template = File.open(settings.pres_template[slide.tpl], "r").read()
          end
        end

        # create html for the slide
        classes = content_classes.join(' ')
        content = "<div data-section=\"#{section}\" data-title=\"#{File.basename(name)}\""
        content += " id=\"#{id}\"" if id
        content += " style=\"background-image: url('file/#{slide.bg}');\"" if slide.bg
        content += " class=\"slide #{classes}\" data-transition=\"#{transition}\">"

        # name the slide. If we've got multiple slides in this file, we'll have a sequence number
        # include that sequence number to index directly into that content
        ref = seq ? "#{name}:#{seq.to_s}" : name
        content += "<div class=\"content #{classes}\" ref=\"#{ref}\">\n"
        @@slide_titles << ref

        # renderers like wkhtmltopdf needs an <h1> tag to use for a section title, but only when printing.
        if opts[:print]
          # reset subsection each time we encounter a new subsection slide. Do this in a regex, because it's much
          # easier to just get the first of any header than it is after rendering to html.
          if content_classes.include? 'subsection'
            @section_title = slide.text.match(/#+ *(.*?)#*$/)[1] rescue settings.showoff_config['name']
          end
          # include a header that's hidden by CSS the renderer can use it, but not be visible
          content += "<h1 class=\"section_title\">#{@section_title}</h1>\n"
        end

        # Apply the template to the slide and replace the key to generate the content of the slide
        sl = process_content_for_replacements(template.gsub(/~~~CONTENT~~~/, slide.text))
        sl = process_content_for_language(sl, I18n.locale)
        sl = Tilt[:markdown].new(nil, nil, @engine_options) { sl }.render
        sl = build_forms(sl, content_classes)
        sl = update_p_classes(sl)
        sl = process_content_for_section_tags(sl, name, opts)
        sl = update_special_content(sl, @slide_count, name) # TODO: deprecated
        sl = update_image_paths(name, sl, opts)

        content += sl
        content += "</div>\n"
        if content_classes.include? 'activity'
          content += '<span class="activityToggle">'
          content += "  <label for=\"activity-#{ref}\">#{I18n.t('activity_complete')}</label>"
          content += "  <input type=\"checkbox\" class=\"activity\" name=\"activity-#{ref}\" id=\"activity-#{ref}\">"
          content += '</span>'
        end
        content += "<canvas class=\"annotations\"></canvas>\n"
        content += "</div>\n"

        content = final_slide_fixup(content)

        final += update_commandline_code(content)

        if seq
          seq += 1
        end
      end
      final
    end

    def process_content_for_language(content, locale)
        lang = locale.to_s.split('-').first
        result = content

        content.scan(/^((~~~LANG:([\w-]+)~~~\n)(.+?)(\n~~~ENDLANG~~~\n))/m).each do |match|
            if match[2] == lang or match[2] == locale.to_s
                result.sub!(match[0], match[3])
            else
                result.sub!(match[0], "\n")
            end
        end

        result
    end

    # This method processes the content of the slide and replaces
    # content markers with their actual value information
    def process_content_for_replacements(content)
      # update counters, incrementing section:minor if needed
      result = content.gsub("~~~CURRENT_SLIDE~~~", @slide_count.to_s)
      result.gsub!("~~~SECTION:MAJOR~~~", @section_major.to_s)
      if result.include? "~~~SECTION:MINOR~~~"
        @section_minor += 1
        result.gsub!("~~~SECTION:MINOR~~~", @section_minor.to_s)
      end

      # scan for pagebreak tags. Should really only be used for handout notes or supplemental materials
      result.gsub!("~~~PAGEBREAK~~~", '<div class="pagebreak">continued...</div>')

      # replace with form rendering placeholder
      result.gsub!(/~~~FORM:([^~]*)~~~/, '<div class="form wrapper" title="\1"></div>')

      # Now check for any kind of options
      content.scan(/(~~~CONFIG:(.*?)~~~)/).each do |match|
        parts = match[1].split('.') # Use dots ('.') to separate Hash keys
        if parts.size > 1
          value = settings.showoff_config.dig(parts[0]).to_h.dig(*parts[1..-1])
        else
          value = settings.showoff_config.fetch(parts[0],nil)
        end

        unless value.is_a?(String)
          msg = "#{match[0]} refers to a non-String data type (#{value.class})"
          msg = "#{match[0]}: not found in settings data" if value.nil?
          @logger.warn(msg)
          next
        end

        result.gsub!(match[0], value)
      end

      # Load and replace any file tags
      content.scan(/(~~~FILE:([^:~]*):?(.*)?~~~)/).each do |match|
        # make a list of code highlighting classes to include
        css  = match[2].split.collect {|i| "language-#{i.downcase}" }.join(' ')

        # get the file content and parse out html entities
        name = match[1]
        file = File.read(File.join(settings.pres_dir, '_files', name)) rescue "Nonexistent file: #{name}"
        file = "Empty file: #{name}" if file.empty?
        file = HTMLEntities.new.encode(file) rescue "HTML parsing of #{name} failed"

        result.gsub!(match[0], "<pre class=\"highlight\"><code class=\"#{css}\">#{file}</code></pre>")
      end

      result.gsub!(/\[(fa\w?)-(\S*)\]/, '<i class="\1 fa-\2"></i>')

      # For fenced code blocks, translate the space separated classes into one
      # colon separated string so Commonmarker doesn't ignore the rest
      result.gsub!(/^`{3} *(.+)$/) {|s| "``` #{$1.split.join(':')}"}

      result
    end

    # replace section tags with classed div tags
    def process_content_for_section_tags(content, name = nil, opts = {})
      return unless content

      # because this is post markdown rendering, we may need to shift a <p> tag around
      # remove the tags if they're by themselves
      result = content.gsub(/<p>~~~SECTION:([^~]*)~~~<\/p>/, '<div class="notes-section \1">')
      result.gsub!(/<p>~~~ENDSECTION~~~<\/p>/, '</div>')

      # shove it around the div if it belongs to the contained element
      result.gsub!(/(<p>)?~~~SECTION:([^~]*)~~~/, '<div class="notes-section \2">\1')
      result.gsub!(/~~~ENDSECTION~~~(<\/p>)?/, '\1</div>')

      # Turn this into a document for munging
      doc = Nokogiri::HTML::DocumentFragment.parse(result)

      filename = File.join(settings.pres_dir, '_notes', "#{name}.md")
      @logger.debug "personal notes filename: #{filename}"
      if [nil, 'notes'].include? opts[:section] and File.file? filename
        # Make sure we've got a notes div to hang personal notes from
        doc.add_child '<div class="notes-section notes"></div>' if doc.css('div.notes-section.notes').empty?
        doc.css('div.notes-section.notes').each do |section|
          text = Tilt[:markdown].new(nil, nil, @engine_options) { File.read(filename) }.render
          frag = "<div class=\"personal\"><h1>#{I18n.t('presenter.notes.personal')}</h1>#{text}</div>"
          note = Nokogiri::HTML::DocumentFragment.parse(frag)

          if section.children.size > 0
            section.children.before(note)
          else
            section.add_child(note)
          end
        end
      end

      doc.css('.callout.glossary').each do |item|
        next unless item.content =~ /^([^|]+)\|([^:]+):(.*)$/
        item['data-term']   = $1
        item['data-target'] = $2
        item['data-text']   = $3
        item.content        = $3

        glossary = (item.attr('class').split - ['callout', 'glossary']).first
        address  = glossary ? "#{glossary}/#{$2}" : $2
        frag     = "<a class=\"processed label\" href=\"glossary://#{address}\">#{$1}</a>"

        item.children.before(Nokogiri::HTML::DocumentFragment.parse(frag))
      end

      # Process links
      doc.css('a').each do |link|
        next unless link['href']
        next if link['href'].start_with? '#'
        next if link['class'].split.include? 'processed' rescue nil

        # If these are glossary links, populate the notes/handouts sections
        if link['href'].start_with? 'glossary://'
          doc.add_child '<div class="notes-section notes"></div>' if doc.css('div.notes-section.notes').empty?
          doc.add_child '<div class="notes-section handouts"></div>' if doc.css('div.notes-section.handouts').empty?

          term = link.content
          text = link['title']
          href = link['href']
          href.slice!('glossary://')

          parts  = href.split('/')
          target = parts.pop
          name   = parts.pop # either the glossary name or nil

          link['class']  = 'term'

          label = link.clone
          label['class'] = 'label processed'

          frag = Nokogiri::HTML::DocumentFragment.parse('<p></p>')
          definition = frag.children.first
          definition['class'] = "callout glossary #{name}"
          definition['data-term']   = term
          definition['data-target'] = target
          definition['data-text']   = text
          definition.content = text
          definition.children.before(label)

          [doc.css('div.notes-section.notes'), doc.css('div.notes-section.handouts')].each do |section|
            section.first.add_child(definition.clone)
          end

        else
          # Add a target so we open all external links from notes in a new window
          link.set_attribute('target', '_blank')
        end
      end

      # finally, remove any sections we don't want to print
      if opts[:section]
        doc.css('div.notes-section').each do |section|
          section.remove unless section.attr('class').split.include? opts[:section]
        end
      end

      doc.to_html
    end

    # TODO: damn, this one is bad. It's named generically so we can add to it if needed.
    #
    #       This method is intended to be the dumping ground for the slide fixups that we can't do in
    #       other places until we get #615 implemented. Then this method should be refactored away.
    #
    def final_slide_fixup(text)
      # Turn this into a document for munging
      doc     = Nokogiri::HTML::DocumentFragment.parse(text)
      slide   = doc.at_css 'div.slide'
      content = doc.at_css 'div.content'

      # move each notes section outside of the content div
      doc.css('div.notes-section').each do |note|
        content.add_next_sibling(note)
      end

      # this is a list of classes that we want applied *only* to content, and not to the slide,
      # typically so that overly aggressive selectors don't match more than they should.
      blacklist = ['bigtext']
      slide['class'] = slide['class'].split.reject { |klass| blacklist.include? klass }.join(' ')

      doc.to_html
    end

    def process_content_for_all_slides(content, num_slides, opts={})
      # this has to be text replacement for now, since the string can appear in any context
      content.gsub!("~~~NUM_SLIDES~~~", num_slides.to_s)
      doc = Nokogiri::HTML::DocumentFragment.parse(content)

      # Should we build a table of contents?
      if opts[:toc]
        toc = Nokogiri::HTML::DocumentFragment.parse("<p id=\"toc\"></p>")

        case opts[:toc]
          when :all
            titles = doc.css('div.slide:not(.toc) > div.content:not(.cover) > h1:not(.section_title)')
          else
            titles = doc.css('div.subsection > h1:not(.section_title)')
        end

        titles.each do |section|
          href = section.parent.parent['id']
          frag = "<div class=\"tocentry\"><a href=\"##{href}\">#{section.content}</a></div>"
          link = Nokogiri::HTML::DocumentFragment.parse(frag)

          toc.children.first.add_child(link)
        end

        # swap out the tag, if found, with the table of contents
        doc.at('p:contains("~~~TOC~~~")').replace(toc) rescue nil
      end

      doc.css('.slide.glossary .content').each do |glossary|
        name = (glossary.attr('class').split - ['content', 'glossary']).first
        list = Nokogiri::HTML::DocumentFragment.parse('<ul class="glossary terms"></ul>')
        seen = []

        doc.css('.callout.glossary').each do |item|
          target = (item.attr('class').split - ['callout', 'glossary']).first

          # if the name matches or if we didn't name it to begin with.
          next unless target == name

          # the definition can exist in multiple places, so de-dup it here
          term = item.attr('data-term')
          next if seen.include? term
          seen << term

          # excrutiatingly find the parent slide content and grab the ref
          # in a library less shitty, this would be something like
          # $(this).parent().siblings('.content').attr('ref')
          href = nil
          item.ancestors('.slide').first.traverse do |element|
            next if element['class'].nil?
            next unless element['class'].split.include? 'content'

            href = element.attr('ref').gsub('/', '_')
          end

          text   = item.attr('data-text')
          link   = item.attr('data-target')
          page   = glossary.attr('ref')
          anchor = "#{page}+#{link}"
          next if href.nil? or text.nil? or link.nil?

          frag = "<li><a id=\"#{anchor}\" class=\"label\">#{term}</a>#{text}<a href=\"##{href}\" class=\"return\">↩</a></li>"
          item = Nokogiri::HTML::DocumentFragment.parse(frag)

          list.children.first.add_child(item)
        end

        glossary.add_child(list)
      end

      # now fix all the links to point to the glossary page
      doc.css('a').each do |link|
        next if link['href'].nil?
        next unless link['href'].start_with? 'glossary://'

        href = link['href']
        href.slice!('glossary://')

        parts  = href.split('/')
        target = parts.pop
        name   = parts.pop # either the glossary name or nil

        classes = name.nil? ? ".slide.glossary" : ".slide.glossary.#{name}"
        href    = doc.at("#{classes} .content").attr('ref') rescue nil

        link['href'] = "##{href}+#{target}"
      end

      doc.to_html
    end

    # Find any lines that start with a <p>.(something), remove the ones tagged with
    # .break and .comment, then turn the remainder into <p class="something">
    # The perlism line noise is splitting multiple classes (.class1.class2) on the period.
    #
    # TODO: We really need to update this to use the DOM instead of text parsing :/
    #
    def update_p_classes(content)
      # comment & break
      content.gsub!(/<p>\.(?:break|comment)( .*)?<\/p>/, '')
      # paragraph classes
      content.gsub!(/<p>\.(.*?) /) { "<p class=\"#{$1.gsub('.', ' ')}\">" }
      # image classes
      content.gsub(/<img src="(.*)" alt="(\.\S*)\s*(.*)">/) { "<img src=\"#{$1}\" class=\"#{$2.gsub('.', ' ')}\" alt=\"#{$3}\">" }
    end

    # replace custom markup with html forms
    def build_forms(content, classes=[])
      title = classes.collect { |cl| $1 if cl =~ /^form=(\w+)$/ }.compact.first
      # only process slides marked as forms
      return content if title.nil?

      begin
        tools =  '<div class="tools">'
        tools << "<input type=\"button\" class=\"display\" value=\"#{I18n.t('forms.display')}\">"
        tools << "<input type=\"submit\" class=\"save\" value=\"#{I18n.t('forms.save')}\" disabled=\"disabled\">"
        tools << '</div>'
        form  = "<form id='#{title}' action='form/#{title}' method='POST'>#{content}#{tools}</form>"
        doc = Nokogiri::HTML::DocumentFragment.parse(form)
        doc.css('p').each do |p|
          if p.text =~ /^(\w*) ?(?:->)? ?(.*)? (\*?)= ?(.*)?$/
            code     = $1
            id       = "#{title}_#{code}"
            name     = $2.empty? ? code : $2
            required = ! $3.empty?
            rhs      = $4

            p.replace form_element(id, code, name, required, rhs, p.text)
          end
        end
        doc.to_html
      rescue Exception => e
        @logger.warn "Form parsing failed: #{e.message}"
        @logger.debug "Backtrace:\n\t#{e.backtrace.join("\n\t")}"
        content
      end
    end

    def form_element(id, code, name, required, rhs, text)
      required = required ? 'required' : ''
      str =  "<div class='form element #{required}' id='#{id}' data-name='#{code}'>"
      str << "<label class='question' for='#{id}'>#{name}</label>"
      case rhs
      when /^\[\s+(\d*)\]$$/             # value = [    5]                                     (textarea)
        str << form_element_textarea(id, code, $1)
      when /^___+(?:\[(\d+)\])?$/        # value = ___[50]                                     (text)
        str << form_element_text(id, code, $1)
      when /^\(.?\)/                     # value = (x) option one (=) opt2 () opt3 -> option 3 (radio)
        str << form_element_radio(id, code, rhs.scan(/\((.?)\)\s*([^()]+)\s*/))
      when /^\[.?\]/                     # value = [x] option one [=] opt2 [] opt3 -> option 3 (checkboxes)
        str << form_element_checkboxes(id, code, rhs.scan(/\[(.?)\] ?([^\[\]]+)/))
      when /^\{(.*)\}$/                  # value = {BOS, [SFO], (NYC)}                         (select shorthand)
        str << form_element_select(id, code, rhs.scan(/[(\[]?\w+[)\]]?/))
      when /^\{$/                        # value = {                                           (select)
        str << form_element_select_multiline(id, code, text)
      when ''                            # value =                                             (radio/checkbox list)
        str << form_element_multiline(id, code, text)
      else
        @logger.warn "Unmatched form element: #{rhs}"
      end
      str << '</div>'
    end

    def form_element_text(id, code, length)
      "<input type='text' id='#{id}_response' name='#{code}' size='#{length}' />"
    end

    def form_element_textarea(id, code, rows)
      rows = 3 if rows.empty?
      "<textarea id='#{id}_response' name='#{code}' rows='#{rows}'></textarea>"
    end

    def form_element_radio(id, code, items)
      form_element_check_or_radio_set('radio', id, code, items)
    end

    def form_element_checkboxes(id, code, items)
      form_element_check_or_radio_set('checkbox', id, code, items)
    end

    def form_element_select(id, code, items)
      str =  "<select id='#{id}_response' name='#{code}'>"
      str << '<option value="">----</option>'

      items.each do |item|
        if item =~ /\((\w+)\)/
          item     = $1
          selected = 'selected'
        else
          selected = ''
        end
        str << "<option value='#{item}' #{selected}>#{item}</option>"
      end
      str << '</select>'
    end

    def form_element_select_multiline(id, code, text)
      str =  "<select id='#{id}_response' name='#{code}'>"
      str << '<option value="">----</option>'

      text.split("\n")[1..-1].each do |item|
        case item
        when /^   +\((\w+) -> (.+)\),?$/         # (NYC -> New York City)
          str << "<option value='#{$1}' selected>#{$2}</option>"
        when /^   +\[(\w+) -> (.+)\],?$/         # [NYC -> New York City]
          str << "<option value='#{$1}' class='correct'>#{$2}</option>"
        when /^   +(\w+) -> (.+),?$/             # NYC -> New, York City
          str << "<option value='#{$1}'>#{$2}</option>"
        when /^   +\((.+)\)$/                    # (Boston)
          str << "<option value='#{$1}' selected>#{$1}</option>"
        when /^   +\[(.+)\]$/                    # [Boston]
          str << "<option value='#{$1}' class='correct'>#{$1}</option>"
        when /^   +([^\(].+[^\),]),?$/           # Boston
          str << "<option value='#{$1}'>#{$1}</option>"
        end
      end
      str << '</select>'
    end

    def form_element_multiline(id, code, text)
      str = '<ul>'

      text.split("\n")[1..-1].each do |item|
        case item
        when /\((.?)\)\s*(\w+)\s*(?:->\s*(.*)?)?/
          modifier = $1
          type     = 'radio'
          value    = $2
          label    = $3 || $2
        when /\[(.?)\]\s*(\w+)\s*(?:->\s*(.*)?)?/
          modifier = $1
          type     = 'checkbox'
          value    = $2
          label    = $3 || $2
        end

        str << '<li>'
        str << form_element_check_or_radio(type, id, code, value, label, modifier)
        str << '</li>'
      end
      str << '</ul>'
    end

    def form_element_check_or_radio_set(type, id, code, items)
      str = ''
      items.each do |item|
        modifier = item[0]

        if item[1] =~ /^(\w*) -> (.*)$/
          value = $1
          label = $2
        else
          value = label = item[1]
        end

        str << form_element_check_or_radio(type, id, code, value, label, modifier)
      end
      str
    end

    def form_element_check_or_radio(type, id, code, value, label, modifier)
      # yes, value and id are conflated, because this is the id of the parent widget
      checked = form_checked?(modifier)
      classes = form_classes(modifier)

      name = (type == 'checkbox') ? "#{code}[]" : code
      str  =  "<input type='#{type}' name='#{name}' id='#{id}_#{value}' value='#{value}' class='#{classes}' #{checked} />"
      str << "<label for='#{id}_#{value}' class='#{classes}'>#{label}</label>"
    end

    def form_classes(modifier)
      modifier.downcase!
      classes = ['response']
      classes << 'correct' if modifier.include?('=')

      classes.join(' ')
    end

    def form_checked?(modifier)
      modifier.downcase.include?('x') ? "checked='checked'" : ''
    end

    # TODO: deprecated
    def update_special_content(content, seq, name)
      doc = Nokogiri::HTML::DocumentFragment.parse(content)
      %w[notes handouts instructor solguide].each { |mark|  update_special_content_mark(doc, mark) }
      update_download_links(doc, seq, name)

      # TODO: what the bloody hell. Figure out how to either make Nokogiri output closed
      # tags or figure out how to get its XML output to quit adding gratuitious spaces.
      doc.to_html.gsub(/(<img [^>]*)>/, '\1 />')
    end

    # TODO: deprecated
    def update_special_content_mark(doc, mark)
      container = doc.css("p.#{mark}").first
      return unless container

      @logger.warn "Special mark (#{mark}) is deprecated. Please replace with section tags. See the README for details."

      # only allow localhost to print the instructor guide
      if mark == 'instructor' and request.env['REMOTE_HOST'] != 'localhost'
        container.remove
      else
        raw      = container.inner_html
        fixed    = raw.gsub(/^\.#{mark} ?/, '')
        markdown = Tilt[:markdown].new { fixed }.render

        container.name       = 'div'
        container.inner_html = markdown
      end
    end
    private :update_special_content_mark

    def update_download_links(doc, seq, name)
      container = doc.css("p.download").first
      return unless container

      raw      = container.text
      fixed    = raw.gsub(/^\.download ?/, '')

      # first create the data structure
      # [ enabled, slide name, [array, of, files] ]
      @@downloads[seq] = [ false, name, [] ]

      fixed.split("\n").each { |file|
        # then push each file onto the list
        @@downloads[seq][2].push(file.strip)
      }

      container.remove
    end
    private :update_download_links

    def update_image_paths(path, slide, opts={:static=>false, :pdf=>false})
      doc       = Nokogiri::HTML::DocumentFragment.parse(slide)
      slide_dir = File.dirname(path)

      case
      when opts[:static] && opts[:pdf]
        replacement_prefix = "file://#{settings.pres_dir}"
      when opts[:static]
        replacement_prefix = './file'
      else
        replacement_prefix = 'image'
      end

      doc.css('img').each do |img|

        # does the image path start from the preso root?
        if img[:src].start_with? '/'
          img_path = img[:src]
        else
          # clean up the path and remove some of the relative nonsense
          img_path = Pathname.new(File.join(slide_dir, img[:src])).cleanpath.to_path
        end
        src       = "#{replacement_prefix}/#{img_path}"
        img[:src] = src

      end
      doc.to_html
    end

    def update_commandline_code(slide)
      html = Nokogiri::HTML::DocumentFragment.parse(slide)
      parser = CommandlineParser.new

      html.css('pre').each do |pre|
        pre.css('code').each do |code|
          out  = code.text
          lang = code.get_attribute('class')

          # Skip this if we've got an empty code block
          next if out.empty?

          # catch fenced code blocks from commonmarker
          if (lang and lang.start_with? 'language-' )
            pre.set_attribute('class', 'highlight')
            # turn the colon separated name back into classes
            code.set_attribute('class', lang.gsub(':', ' '))

          # or we've started a code block with a Showoff language tag
          elsif out.strip[0, 3] == '@@@'
            lines = out.split("\n")
            lang  = lines.shift.gsub('@@@', '').strip
            pre.set_attribute('class', 'highlight')
            code.set_attribute('class', 'language-' + lang.downcase) if !lang.empty?
            code.content = lines.join("\n")
          end

        end
      end

      html.css('.commandline > pre > code').each do |code|
        out = code.text
        code.content = ''
        tree = parser.parse(out)
        transform = Parslet::Transform.new do
          rule(:prompt => simple(:prompt), :input => simple(:input), :output => simple(:output)) do
            command = Nokogiri::XML::Node.new('code', html)
            command.set_attribute('class', 'command')
            command.content = "#{prompt} #{input}"
            code << command

            # Add newline after the input so that users can
            # advance faster than the typewriter effect
            # and still keep inputs on separate lines.
            code << "\n"

            unless output.to_s.empty?

              result = Nokogiri::XML::Node.new('code', html)
              result.set_attribute('class', 'result')
              result.content = output
              code << result
            end
          end
        end
        transform.apply(tree)
      end
      html.to_html
    end

    def get_slides_html(opts={:static=>false, :pdf=>false, :toc=>false, :supplemental=>nil, :section=>nil})
      sections = nil
      Dir.chdir(get_locale_dir('locales', @locale)) do
        sections = ShowOffUtils.showoff_sections(settings.pres_dir, settings.showoff_config, @logger)
      end

      if sections
        data = ''
        sections.each do |section, slides|
          slides.each do |filename|
            next unless filename.end_with? '.md'
            path = filename.chomp('.md') # TODO: I don't know why we do this silly thing
            begin
              data << process_markdown(path, section, File.read(filename), opts)
            rescue Errno::ENOENT => e
              @logger.error e.message
              data << process_markdown(path, section, "!SLIDE\n# Missing File!\n## #{filename}", opts)
            end
          end

# I don't know what this part was supposed to do
#           if section =~ /^#/
#             name = section.each_line.first.gsub(/^#*/,'').strip
#             data << process_markdown(name, "<!SLIDE subsection>\n" + section, opts)
#           else

        end
      end
      process_content_for_all_slides(data, @slide_count, opts)
    end

    def inline_css(csses, pre = nil)
      css_content = '<style type="text/css">'
      csses.each do |css_file|
        if pre
          css_file = File.join(File.dirname(__FILE__), '..', pre, css_file)
        else
          css_file = File.join(settings.pres_dir, css_file)
        end
        css_content += File.read(css_file)
      end
      css_content += '</style>'
      css_content
    end

    def inline_js(jses, pre = nil)
      js_content = '<script type="text/javascript">'
      jses.each do |js_file|
        if pre
          js_file = File.join(File.dirname(__FILE__), '..', pre, js_file)
        else
          js_file = File.join(settings.pres_dir, js_file)
        end

        begin
          js_content += File.read(js_file)
        rescue Errno::ENOENT
          $stderr.puts "WARN: Failed to inline JS. No such file: #{js_file}"
          next
        end
      end
      js_content += '</script>'
      js_content
    end

    def inline_all_js(jses_directory)
       inline_js(Dir.entries(File.join(File.dirname(__FILE__), '..', jses_directory)).find_all{|filename| filename.length > 2 }, jses_directory)
    end

    def index(static=false)
      if static
        @title = ShowOffUtils.showoff_title(settings.pres_dir)
        @slides = get_slides_html(:static=>static)
        @pause_msg = ShowOffUtils.pause_msg
      end

      # Display favicon in the window if configured
      @favicon  = settings.showoff_config['favicon']

      # Check to see if the presentation has enabled feedback
      @feedback = settings.showoff_config['feedback'] unless (params && params[:feedback] == 'false')

      # If we're static, we need to not show the downloads page
      @static   = static

      # Provide a button in the sidebar for interactive editing if configured
      @edit     = settings.showoff_config['edit'] if @review

      # translated UI strings, according to the current locale
      @language = get_translations()

      # store a cookie to tell clients apart. More reliable than using IP due to proxies, etc.
      manage_client_cookies()

      erb :index
    end

    def presenter
      @favicon   = settings.showoff_config['favicon']
      @issues    = settings.showoff_config['issues']
      @edit      = settings.showoff_config['edit'] if @review
      @feedback  = settings.showoff_config['feedback']
      @language  = get_translations()

      manage_client_cookies(true)

      erb :presenter
    end

    def clean_link(href)
      if href && href[0, 1] == '/'
        href = href[1, href.size]
      end
      href
    end

    def assets_needed
      assets = ["index", "slides"]

      index = erb :index
      html = Nokogiri::XML.parse(index)
      html.css('head link').each do |link|
        href = clean_link(link['href'])
        assets << href if href
      end
      html.css('head script').each do |link|
        href = clean_link(link['src'])
        assets << href if href
      end

      slides = get_slides_html
      html = Nokogiri::XML.parse("<slides>" + slides + "</slides>")
      html.css('img').each do |link|
        href = clean_link(link['src'])
        assets << href if href
      end

      css = Dir.glob("#{settings.public_folder}/**/*.css").map { |path| path.gsub(settings.public_folder + '/', '') }
      assets << css

      js = Dir.glob("#{settings.public_folder}/**/*.js").map { |path| path.gsub(settings.public_folder + '/', '') }
      assets << js

      assets.uniq.join("\n")
    end

    def slides(static=false, merged=false)
      @logger.info "Cached presentations: #{@@cache.keys}"

      # if we have a cache and we're not asking to invalidate it
      return @@cache[@locale] if (@@cache[@locale] and params['cache'] != 'clear')

      @logger.info "Generating locale: #{@locale}"

      # If we're displaying from a repository, let's update it
      ShowOffUtils.update(settings.verbose) if settings.url

      @@slide_titles = []
      content = get_slides_html(:static=>static, :merged=>merged)

      # allow command line cache disabling
      @@cache[@locale] = content unless settings.nocache
      content
    end

    def print(section=nil, munged=false)
      @slides = get_slides_html(:static=>true, :toc=>true, :print=>true, :section=>section)
      @favicon = settings.showoff_config['favicon']

      unless munged
        @baseurl = '../' * section.split('/').count
      end

      erb :onepage
    end

    def supplemental(content, static=false)
      # supplemental material is by definition separate from the presentation, so it doesn't make sense to attach notes
      @slides = get_slides_html(:static=>static, :supplemental=>content, :section=>false, :toc=>:all)
      @favicon = settings.showoff_config['favicon']
      @wrapper_classes = ['supplemental']
      erb :onepage
    end

    def download()
      begin
        shared = Dir.glob("#{settings.pres_dir}/_files/share/*").map { |path| File.basename(path) }
        # We use the icky -999 magic index because it has to be comparable for the view sort
        @downloads = { -999 => [ true, 'Shared Files', shared ] }
        @favicon = settings.showoff_config['favicon']
      rescue Errno::ENOENT => e
        # don't fail if the directory doesn't exist
        @downloads = {}
      end
      @downloads.merge! @@downloads
      erb :download
    end

    def stats_data()
      data = {}
      begin

        # what are viewers looking at right now?
        now = Time.now.to_i # let's throw away viewers who haven't done anything in 5m
        active  = @@counter['current'].select {|client, view| (now - view[1]).abs < 300 }

        # percentage of stray viewers
        stray   = active.select {|client, view| view[0] != @@current[:name] }
        stray_p = ((stray.size.to_f / active.size.to_f) * 100).to_i rescue 0
        data['stray_p'] = stray_p

        # percentage of idle viewers
        idle    = @@counter['current'].size - active.size
        idle_p  = ((idle.to_f / @@counter['current'].size.to_f) * 100).to_i rescue 0
        data['idle_p']  = idle_p

        viewers = @@slide_titles.map do |slide|
          count = active.select {|client, view| view[0] == slide }.size
          flags = (slide == @@current[:name]) ? 'current' : nil
          [count, slide, nil, flags]
        end

        # trim the ends, if nobody's looking we don't much care.
        viewers.pop while viewers.last[0] == 0
        viewers.shift while viewers.first[0] == 0
        viewmax = viewers.max_by {|view| view[0] }.first

        data['viewers'] = viewers
        data['viewmax'] = viewmax
      rescue => e
        @logger.warn "Not enough data to generate pageviews."
        @logger.debug e.message
        @logger.debug e.backtrace.first
      end

      begin
        # current elapsed time for the zoomline view
        elapsed = @@slide_titles.map do |slide|
          if @@counter['pageviews'][slide].nil?
            time = 0
          else
            time = @@counter['pageviews'][slide].inject(0) do |outer, (viewer, views)|
              outer += views.inject(0) { |inner, view| inner += view['elapsed'] }
            end
          end
          string = Time.at(time).gmtime.strftime('%M:%S')
          flags  = (slide == @@current[:name]) ? 'current' : nil

          [ time, slide, string, flags ]
        end
        maxtime = elapsed.max_by {|view| view[0] }.first

        data['elapsed'] = elapsed
        data['maxtime'] = maxtime
      rescue => e
        # expected if this is loaded before a presentation has been compiled
        @logger.warn "Not enough data to generate elapsed time."
        @logger.debug e.message
        @logger.debug e.backtrace.first
      end

      data.to_json
    end

    def stats()
      if localhost?
        # the presenter should have full stats in the erb
        @counter = @@counter['pageviews']
      end

      # for the full page view. Maybe to be disappeared
      @all = Hash.new
      @@counter['pageviews'].each do |slide, stats|
        @all[slide] = 0
        stats.map do |host, visits|
          visits.each { |entry| @all[slide] += entry['elapsed'].to_f }
        end
      end

      erb :stats
    end

    def pdf(name)
      @slides = get_slides_html(:static=>true, :toc=>true, :print=>true)
      @inline = true

      html = erb :onepage

      # Process inline css and js for included images
      # The css uses relative paths for images and we prepend the file url
      html.gsub!(/url\([\"\']?(?!https?:\/\/)(.*?)[\"\']?\)/) do |s|
        "url(file://#{settings.pres_dir}/#{$1})"
      end

      # remove the weird /files component, since that doesn't exist on the filesystem
      # replace it for file://<PATH> for correct use with wkhtmltopdf (exactly with qt-webkit)
      html.gsub!(/<img src=".\/file\/([^"]*)/) do |s|
        "<img src=\"file:\/\/#{settings.pres_dir}\/#{$1}"
      end

      # PDFKit.new takes the HTML and any options for wkhtmltopdf
      # run `wkhtmltopdf --extended-help` for a full list of options
      kit = PDFKit.new(html, ShowOffUtils.showoff_pdf_options(settings.pres_dir))

      # Save the PDF to a file
      kit.to_file(name)
    end

  end


  def self.do_static(args, opts = {})
      args ||= [] # handle nil arguments
      what   = args[0] || "index"
      opt    = args[1]

      ShowOffUtils.presentation_config_file = opts[:f]

      # Sinatra now aliases new to new!
      # https://github.com/sinatra/sinatra/blob/v1.3.3/lib/sinatra/base.rb#L1369
      showoff = ShowOff.new!

      name = showoff.instance_variable_get(:@pres_name)
      path = showoff.instance_variable_get(:@root_path)
      logger = showoff.instance_variable_get(:@logger)

      I18n.locale = opts[:language]

      case what
      when 'supplemental'
        data = showoff.send(what, opt, true)
      when 'pdf'
        opt ||= "#{name}.pdf"
        data = showoff.send(what, opt)
      when 'print'
        opt ||= 'handouts'
        data = showoff.send(what, opt, true)
      else
        data = showoff.send(what, true)
      end

      if data.is_a?(File)
        logger.warn "Generated PDF as #{opt}"
      else
        out = File.expand_path("#{path}/static")
        # First make a directory
        FileUtils.makedirs(out)
        # Then write the html
        file = File.new("#{out}/index.html", "w")
        file.puts(data)
        file.close
        # Now copy all the js and css
        my_path = File.join( File.dirname(__FILE__), '..', 'public')
        ["js", "css"].each { |dir|
          FileUtils.copy_entry("#{my_path}/#{dir}", "#{out}/#{dir}", false, false, true)
        }
        # And copy the directory
        Dir.glob("#{my_path}/#{name}/*").each { |subpath|
          base = File.basename(subpath)
          next if "static" == base
          next unless File.directory?(subpath) || base.match(/\.(css|js)$/)
          FileUtils.copy_entry(subpath, "#{out}/#{base}")
        }

        # Set up file dir
        file_dir = File.join(out, 'file')
        FileUtils.makedirs(file_dir)
        pres_dir = showoff.settings.pres_dir

        # ..., copy all user-defined styles and javascript files
        showoff.css_files.each { |path|
          dest = File.join(file_dir, path)
          FileUtils.mkdir_p(File.dirname(dest))
          FileUtils.copy(path, dest)
        }

        # ... and copy all needed image files
        [/img src=[\"\'].\/file\/(.*?)[\"\']/, /style=[\"\']background(?:-image): url\(\'file\/(.*?)'/].each do |regex|
          data.scan(regex).flatten.each do |path|
            dir = File.dirname(path)
            FileUtils.makedirs(File.join(file_dir, dir))
            begin
              FileUtils.copy(File.join(pres_dir, path), File.join(file_dir, path))
            rescue Errno::ENOENT => e
              puts "Missing source file: #{path}"
            end
          end
        end
        # copy images from css too
        showoff.css_files.each do |css_path|
          File.open(css_path) do |file|
            data = file.read
            data.scan(/url\([\"\']?(?!https?:\/\/)(.*?)[\"\']?\)/).flatten.each do |path|
              path.gsub!(/(\#.*)$/, '') # get rid of the anchor
              path.gsub!(/(\?.*)$/, '') # get rid of the query

              # resolve relative paths in the stylesheet
              path = "#{File.dirname(css_path)}/#{path}" unless path.start_with? '/'

              logger.debug path
              dir = File.dirname(path)
              FileUtils.makedirs(File.join(file_dir, dir))
              begin
                FileUtils.copy(File.join(pres_dir, path), File.join(file_dir, path))
              rescue Errno::ENOENT => e
                puts "Missing source file: #{path}"
              end
            end
          end
        end
      end
    end

  # Load a slide file from disk, parse it and return the text of a code block by index
  def get_code_from_slide(path, index, executable=true)
    if path =~ /^(.*)(?::)(\d+)$/
      path = $1
      num  = $2.to_i
    else
      num = 1
    end

    classes = executable ? 'code.execute' : 'code'

    slide = "#{path}.md"
    return [] unless File.exist? slide

    content = File.read(slide)
    return [] if content.nil?
    return [] if content.empty?

    if defined? num
      content = content.split(/^\<?!SLIDE/m).reject { |sl| sl.empty? }[num-1]
    end

    html = process_markdown(slide, '', content, {})
    doc  = Nokogiri::HTML::DocumentFragment.parse(html)

    if index == 'all'
      doc.css(classes).collect do |code|
        classes = code.attr('class').split rescue []
        lang    = classes.shift =~ /language-(\S*)/ ? $1 : nil

        [lang, code.text.gsub(/^\* /, ' '), classes]
      end
    else
      doc.css(classes)[index.to_i].text.gsub(/^\* /, ' ') rescue 'Invalid code block index'
    end
  end

  # Basic auth boilerplate
  def protected!
    unless authorized?
      response['WWW-Authenticate'] = %(Basic realm="#{@title}: Protected Area. Please log in.")
      throw(:halt, [401, "Not authorized."])
    end
  end

  def locked!
    # check auth first, because if the presenter has logged in with a password, we don't want to prompt again
    unless authorized? or unlocked?
      response['WWW-Authenticate'] = %(Basic realm="#{@title}: Locked Area. A presentation key is required to view.")
      throw(:halt, [401, "Not authorized."])
    end
  end

  def authorized?
    # allow localhost if we have no password
    if not settings.showoff_config.has_key? 'password'
      localhost?
    else
      user     = settings.showoff_config['user'] || ''
      password = settings.showoff_config['password']
      authenticate([user, password])
    end
  end

  def unlocked?
    # allow localhost if we have no key
    if not settings.showoff_config.has_key? 'key'
      localhost?
    else
      authenticate(settings.showoff_config['key'])
    end
  end

  def localhost?
    request.env['REMOTE_HOST'] == 'localhost' or request.ip == '127.0.0.1'
  end

  def authenticate(credentials)
    auth = Rack::Auth::Basic::Request.new(request.env)

    return false unless auth.provided? && auth.basic? && auth.credentials

    case credentials
    when Array
       auth.credentials == credentials
    when String
      auth.credentials.last == credentials
    else
      false
    end
  end

  def guid
    # this is a terrifyingly simple GUID generator
    (0..15).to_a.map{|a| rand(16).to_s(16)}.join
  end

  def valid_presenter_cookie?
    return false if @@cookie.nil?
    (request.cookies['presenter'] == @@cookie)
  end

  def master_presenter?
    @@master == @client_id
  end

  def manage_client_cookies(presenter=false)
    # store a cookie to tell clients apart. More reliable than using IP due to proxies, etc.
    if request.nil?   # when running showoff static
      @client_id = guid()
    else
      if request.cookies['client_id']
        @client_id = request.cookies['client_id']
      else
        @client_id = guid()
        response.set_cookie('client_id', @client_id)
      end

      # if we have no content translations then remove the cookie
      response.delete_cookie('locale') if language_names.empty?
    end

    if presenter
      @@master ||= @client_id
      @@cookie ||= guid()
      response.set_cookie('presenter', @@cookie)
    end
  end

  post '/form/:id' do |id|
    client_id = request.cookies['client_id']
    @logger.warn("Saving form answers from ip:#{request.ip} with ID of #{client_id} for id:##{id}")

    form = params.reject { |k,v| ['splat', 'captures', 'id'].include? k }

    # make sure we've got a bucket for this form, then save our answers
    @@forms[id] ||= {}
    @@forms[id][client_id] = form

    form.to_json
  end

  # Return a list of the totals for each alternative for each question of a form
  get '/form/:id' do |id|
    return nil unless @@forms.has_key? id

    @@forms[id].each_with_object({}) do |(ip,form), sum|
      form.each do |key, val|
        # initialize the object with an empty response if needed
        sum[key] ||= { 'count' => 0, 'responses' => {} }

        # increment the number of unique responses we've seen
        sum[key]['count'] += 1

        responses = sum[key]['responses']
        if val.class == Array
          val.each do |item|
            responses[item] ||= 0
            responses[item]  += 1
          end
        else
          responses[val] ||= 0
          responses[val]  += 1
        end
      end
    end.to_json
  end

  # Evaluate known good code from a slide file on disk.
  get '/execute/:lang' do |lang|
    return 'Run showoff with -x or --executecode to enable code execution' unless @execute

    code   = get_code_from_slide(params[:path], params[:index])
    parser = settings.showoff_config['parsers'][lang]

    return "No parser for #{lang}" unless parser

    require 'timeout'
    require 'open3' # for 1.8 compatibility :/
    begin
      Timeout::timeout(settings.showoff_config['timeout']) do
        # write out a tempfile to make it simpler for end users to add custom language parser
        Tempfile.open('showoff-execution') do |f|
          File.write(f.path, code)
          @logger.debug "Evaluating: #{parser} #{f.path}"
          output, status = Open3.capture2e("#{parser} #{f.path}")

          unless status.success?
            @logger.warn "Command execution failed for #{params[:path]}[#{params[:index]}]"
            @logger.warn output
          end

          output
        end
      end
    rescue => e
      e.message
    end.gsub(/\n/, '<br />')
  end

  # provide a callback to trigger a local file editor, but only when called when viewing from localhost.
  get '/edit/*' do |path|
    # Docs suggest that old versions of Sinatra might provide an array here, so just make sure.
    filename = path.class == Array ? path.first : path
    @logger.debug "Editing #{filename}"

    # When a relative path is used, it's sometimes fully expanded. But then when
    # it's passed via URL, the initial slash is lost. Here we try to get it back.
    filename = "/#{filename}" unless File.exist? filename
    return unless File.exist? filename

    if request.host != 'localhost'
      @logger.warn "Disallowing edit because #{request.host} isn't localhost."
      return
    end

    case RUBY_PLATFORM
    when /darwin/
      `open #{filename}`
    when /linux/
      `xdg-open #{filename}`
    when /cygwin|mswin|mingw|bccwin|wince|emx/
      `start #{filename}`
    else
      @logger.warn "Cannot open #{filename}, unknown platform #{RUBY_PLATFORM}."
    end
  end

  get %r{(?:image|file)/(.*)} do
    path = params[:captures].first
    full_path = File.join(settings.pres_dir, path)
    if File.exist?(full_path)
        send_file full_path
    else
        raise Sinatra::NotFound
    end
  end

  get '/control' do
    # leave the route so we don't have 404's for the parts we've missed
    return nil unless @interactive

    if !request.websocket?
      raise Sinatra::NotFound
    else
      request.websocket do |ws|
        ws.onopen do
          ws.send( { 'message' => 'current', 'current' => @@current[:number] }.to_json )
          settings.sockets << ws

          @logger.warn "Open sockets: #{settings.sockets.size}"
        end
        ws.onmessage do |data|
          begin
            control = JSON.parse(data)

            @logger.debug "#{control.inspect}"

            case control['message']
            when 'update'
              # websockets don't use the same auth standards
              # we use a session cookie to identify the presenter
              if valid_presenter_cookie?
                name  = control['name']
                slide = control['slide'].to_i
                increment = control['increment'].to_i rescue 0

                # check to see if we need to enable a download link
                if @@downloads.has_key?(slide)
                  @logger.debug "Enabling file download for slide #{name}"
                  @@downloads[slide][0] = true
                end

                # update the current slide pointer
                @logger.debug "Updated current slide to #{name}"
                @@current = { :name => name, :number => slide, :increment => increment }

                # schedule a notification for all clients
                EM.next_tick { settings.sockets.each{|s| s.send({ 'message' => 'current', 'current' => @@current[:number], 'increment' => @@current[:increment] }.to_json) } }
              end

            when 'register'
              # save a list of presenters
              if valid_presenter_cookie?
                remote = request.env['REMOTE_HOST'] || request.env['REMOTE_ADDR']
                settings.presenters << ws
                @logger.warn "Registered new presenter: #{remote}"
              end

            when 'track'
              remote = valid_presenter_cookie? ? 'presenter' : request.cookies['client_id']
              slide  = control['slide']

              if control.has_key? 'time'
                time = control['time'].to_f

                # record the UA of the client if we haven't seen it before
                @@counter['user_agents'][remote] ||= request.user_agent

                views = @@counter['pageviews']
                # a bucket for this slide
                views[slide] ||= Hash.new
                # a bucket of slideviews for this address
                views[slide][remote] ||= Array.new
                # and add this slide viewing to the bucket
                views[slide][remote] << { 'elapsed' => time, 'timestamp' => Time.now.to_i, 'presenter' => @@current[:name] }

                @logger.debug "Logged #{time} on slide #{slide} for #{remote}"

              else
                @@counter['current'][remote] = [slide, Time.now.to_i]
                @logger.debug "Recorded current slide #{slide} for #{remote}"
              end

            when 'position'
              ws.send( { 'message' => 'current', 'current' => @@current[:number] }.to_json ) unless @@cookie.nil?

            when 'activity'
              next if valid_presenter_cookie?
              remote = request.cookies['client_id']
              slide  = control['slide']
              status = control['status']
              @@activity[slide] ||= {}
              @@activity[slide][remote] = status

              current  = @@current[:number]
              activity = @@activity[current] rescue nil

              @logger.debug "Current activity status: #{activity.inspect}"
              if activity
                # select all activity on this slide where completion status is false
                count = activity.select {|viewer, status| status == false }.size
                EM.next_tick { settings.presenters.each{|s| s.send({ 'message' => 'activity', 'count' => count }.to_json) } }
              end

            when 'pace', 'question', 'cancel'
              # just forward to the presenter(s) along with a debounce in case a presenter is registered twice
              control['id'] = guid()
              EM.next_tick { settings.presenters.each{|s| s.send(control.to_json) } }

            when 'complete', 'answerkey'
              EM.next_tick { settings.sockets.each{|s| s.send(control.to_json) } }

            when 'annotation', 'annotationConfig'
              EM.next_tick { (settings.sockets - settings.presenters).each{|s| s.send(control.to_json) } }

            when 'feedback'
              filename = "#{settings.statsdir}/#{settings.feedback}"
              slide    = control['slide']
              rating   = control['rating']
              feedback = control['feedback']

              begin
                log = JSON.parse(File.read(filename))
              rescue
                # do nothing
              end

              log        ||= Hash.new
              log[slide] ||= Array.new
              log[slide]  << { :rating => rating, :feedback => feedback }

              if settings.verbose then
                File.write(filename, JSON.pretty_generate(log))
              else
                File.write(filename, log.to_json)
              end

            else
              @logger.warn "Unknown message <#{control['message']}> received."
              @logger.warn control.inspect
            end

          rescue Exception => e
            @logger.warn "Messaging error: #{e}"
            @logger.debug e.backtrace.join("\n")
          end
        end
        ws.onclose do
          @logger.warn("websocket closed")
          settings.sockets.delete(ws)
        end
      end
    end
  end

  # gawd, this whole routing scheme is bollocks
  get %r{/([^/]*)/?([^/]*)} do
    @locale    = locale(request.cookies['locale'])
    @title     = ShowOffUtils.showoff_title(settings.pres_dir)
    @pause_msg = ShowOffUtils.pause_msg
    what = params[:captures].first
    opt  = params[:captures][1]
    what = 'index' if "" == what

    if settings.showoff_config['protected'].include? what
      protected!
    elsif settings.showoff_config['locked'].include? what
      locked!
    end

    begin
      if (what != "favicon.ico")
        if ['supplemental', 'print'].include? what
          data = send(what, opt)
        else
          data = send(what)
        end
        if data.is_a?(File)
          send_file data.path
        else
          data
        end
      end
    rescue NoMethodError => e
      @logger.warn "Invalid object #{what} requested."
      @logger.warn e.message
      @logger.debug e.backtrace.join("\n")
      raise Sinatra::NotFound
    end
  end

  not_found do
    @env = request.env
    erb :'404'
  end

  at_exit do
    ShowOff.flush
  end

end
