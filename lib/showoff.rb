require 'rubygems'
require 'sinatra/base'
require 'json'
require 'nokogiri'
require 'fileutils'
require 'logger'
require 'htmlentities'
require 'sinatra-websocket'

here = File.expand_path(File.dirname(__FILE__))
require "#{here}/showoff_utils"
require "#{here}/commandline_parser"

begin
  require 'RMagick'
rescue LoadError
  # nop
end

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
  set :review, false

  set :pres_dir, '.'
  set :pres_file, 'showoff.json'
  set :page_size, "Letter"
  set :pres_template, nil
  set :showoff_config, {}
  set :encoding, nil

  def initialize(app=nil)
    super(app)
    @logger = Logger.new(STDOUT)
    @logger.formatter = proc { |severity,datetime,progname,msg| "#{progname} #{msg}\n" }
    @logger.level = settings.verbose ? Logger::DEBUG : Logger::WARN

    @review = settings.review

    dir = File.expand_path(File.join(File.dirname(__FILE__), '..'))
    @logger.debug(dir)

    showoff_dir = File.expand_path(File.join(File.dirname(__FILE__), '..'))
    settings.pres_dir ||= Dir.pwd
    @root_path = "."

    settings.pres_dir = File.expand_path(settings.pres_dir)
    if (settings.pres_file)
      ShowOffUtils.presentation_config_file = settings.pres_file
    end

    # Load configuration for page size and template from the
    # configuration JSON file
    if File.exists?(ShowOffUtils.presentation_config_file)
      showoff_json = JSON.parse(File.read(ShowOffUtils.presentation_config_file))
      settings.showoff_config = showoff_json

      # Set options for encoding, template and page size
      settings.encoding = showoff_json["encoding"]
      settings.page_size = showoff_json["page-size"] || "Letter"
      settings.pres_template = showoff_json["templates"]

      @highlightStyle = showoff_json['highlight'] || 'default'
    end

    @logger.debug settings.pres_template

    @cached_image_size = {}
    @logger.debug settings.pres_dir
    @pres_name = settings.pres_dir.split('/').pop
    require_ruby_files

    # Default asset path
    @asset_path = "./"

    # Create stats directory
    FileUtils.mkdir settings.statsdir unless File.directory? settings.statsdir

    # Page view time accumulator. Tracks how often slides are viewed by the audience
    begin
      @@counter = JSON.parse(File.read("#{settings.statsdir}/#{settings.viewstats}"))
    rescue
      @@counter = Hash.new
    end

    # keeps track of form responses. In memory to avoid concurrence issues.
    begin
      @@forms = JSON.parse(File.read("#{settings.statsdir}/#{settings.forms}"))
    rescue
      @@forms = Hash.new
    end

    @@downloads = Hash.new # Track downloadable files
    @@cookie    = nil      # presenter cookie. Identifies the presenter for control messages
    @@current   = Hash.new # The current slide that the presenter is viewing

    # flush stats to disk periodically
    Thread.new do
      loop do
        sleep 30
        ShowOff.flush
      end
    end

    # Initialize Markdown Configuration
    MarkdownConfig::setup(settings.pres_dir)
  end

  # save stats to disk
  def self.flush
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
  end

  def self.pres_dir_current
    opt = {:pres_dir => Dir.pwd}
    ShowOff.set opt
  end

  def require_ruby_files
    Dir.glob("#{settings.pres_dir}/*.rb").map { |path| require path }
  end

  helpers do
    def load_section_files(section)
      section = File.join(settings.pres_dir, section)
      files = if File.directory? section
        Dir.glob("#{section}/**/*").sort
      else
        [section]
      end
      @logger.debug files
      files
    end

    def css_files
      Dir.glob("#{settings.pres_dir}/*.css").map { |path| File.basename(path) }
    end

    def js_files
      Dir.glob("#{settings.pres_dir}/*.js").map { |path| File.basename(path) }
    end


    def preshow_files
      Dir.glob("#{settings.pres_dir}/_preshow/*").map { |path| File.basename(path) }.to_json
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

    def process_markdown(name, content, opts={:static=>false, :pdf=>false, :print=>false, :toc=>false, :supplemental=>nil})
      if settings.encoding and content.respond_to?(:force_encoding)
        content.force_encoding(settings.encoding)
      end
      engine_options = ShowOffUtils.showoff_renderer_options(settings.pres_dir)
      @logger.debug "renderer: #{Tilt[:markdown].name}"
      @logger.debug "render options: #{engine_options.inspect}"

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
              File.exists?(settings.pres_template[slide.tpl])
            template = File.open(settings.pres_template[slide.tpl], "r").read()
          end
        end

        # create html for the slide
        classes = content_classes.join(' ')
        content = "<div"
        content += " id=\"#{id}\"" if id
        content += " style=\"background-image: url('file/#{slide.bg}');\"" if slide.bg
        content += " class=\"slide #{classes}\" data-transition=\"#{transition}\">"

        # name the slide. If we've got multiple slides in this file, we'll have a sequence number
        # include that sequence number to index directly into that content
        if seq
          content += "<div class=\"content #{classes}\" ref=\"#{name}/#{seq.to_s}\">\n"
        else
          content += "<div class=\"content #{classes}\" ref=\"#{name}\">\n"
        end

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
        sl = Tilt[:markdown].new(nil, nil, engine_options) { sl }.render
        sl = build_forms(sl, content_classes)
        sl = update_p_classes(sl)
        sl = process_content_for_section_tags(sl, name)
        sl = update_special_content(sl, @slide_count, name) # TODO: deprecated
        sl = update_image_paths(name, sl, opts)

        content += sl
        content += "</div>\n"
        content += "</div>\n"

        final += update_commandline_code(content)

        if seq
          seq += 1
        end
      end
      final
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
      result.gsub!("~~~PAGEBREAK~~~", '<div class="break">continued...</div>')

      # replace with form rendering placeholder
      result.gsub!(/~~~FORM:([^~]*)~~~/, '<div class="form wrapper" title="\1"></div>')

      # Now check for any kind of options
      content.scan(/(~~~CONFIG:(.*?)~~~)/).each do |match|
        result.gsub!(match[0], settings.showoff_config[match[1]]) if settings.showoff_config.key?(match[1])
      end

      # Load and replace any file tags
      content.scan(/(~~~FILE:([^:]*):?(.*)?~~~)/).each do |match|
        # get the file content and parse out html entities
        file = HTMLEntities.new.encode(File.read(File.join(settings.pres_dir, '_files', match[1])))

        # make a list of sh_highlight classes to include
        css  = match[2].split.collect {|i| "sh_#{i.downcase}" }.join(' ')

        result.gsub!(match[0], "<pre class=\"#{css}\"><code>#{file}</code></pre>")
      end

      result
    end

    # replace section tags with classed div tags
    def process_content_for_section_tags(content, name = nil)
      return unless content

      # because this is post markdown rendering, we may need to shift a <p> tag around
      # remove the tags if they're by themselves
      result = content.gsub(/<p>~~~SECTION:([^~]*)~~~<\/p>/, '<div class="\1">')
      result.gsub!(/<p>~~~ENDSECTION~~~<\/p>/, '</div>')

      # shove it around the div if it belongs to the contained element
      result.gsub!(/(<p>)?~~~SECTION:([^~]*)~~~/, '<div class="\2">\1')
      result.gsub!(/~~~ENDSECTION~~~(<\/p>)?/, '\1</div>')

      filename = File.join(settings.pres_dir, '_notes', "#{name}.md")
      @logger.debug "personal notes filename: #{filename}"
      if File.file? filename
        # TODO: shouldn't have to reparse config all the time
        engine_options = ShowOffUtils.showoff_renderer_options(settings.pres_dir)

        doc = Nokogiri::HTML::DocumentFragment.parse(result)
        # Make sure we've got a notes div to hang personal notes from
        doc.add_child '<div class="notes"></div>' if doc.css('div.notes').empty?
        doc.css('div.notes').each do |section|
          text = Tilt[:markdown].new(nil, nil, engine_options) { File.read(filename) }.render
          frag = "<div class=\"personal\"><h1>Personal Notes</h1>#{text}</div>"
          note = Nokogiri::HTML::DocumentFragment.parse(frag)

          if section.children.size > 0
            section.children.before(note)
          else
            section.add_child(note)
          end
        end
        result = doc.to_html
      end
      result
    end

    def process_content_for_all_slides(content, num_slides, opts={})
      content.gsub!("~~~NUM_SLIDES~~~", num_slides.to_s)

      # Should we build a table of contents?
      if opts[:toc]
        frag = Nokogiri::HTML::DocumentFragment.parse ""
        toc = Nokogiri::XML::Node.new('div', frag)
        toc['id'] = 'toc'
        frag.add_child(toc)

        Nokogiri::HTML(content).css('div.subsection > h1:not(.section_title)').each do |section|
          entry = Nokogiri::XML::Node.new('div', frag)
          entry['class'] = 'tocentry'
          toc.add_child(entry)

          link = Nokogiri::XML::Node.new('a', frag)
          link['href'] = "##{section.parent.parent['id']}"
          link.content = section.content
          entry.add_child(link)
        end

        # swap out the tag, if found, with the table of contents
        content.gsub!("~~~TOC~~~", frag.to_html)
      end

      content
    end

    # find any lines that start with a <p>.(something) and turn them into <p class="something">
    def update_p_classes(markdown)
      markdown.gsub(/<p>\.(.*?) /, '<p class="\1">')
    end

    # replace custom markup with html forms
    def build_forms(content, classes=[])
      title = classes.collect { |cl| $1 if cl =~ /^form=(\w+)$/ }.compact.first
      # only process slides marked as forms
      return content if title.nil?

      begin
        tools =  '<div class="tools">'
        tools << '<input type="button" class="display" value="Display Results">'
        tools << '<input type="submit" value="Save" disabled="disabled">'
        tools << '</div>'
        form  = "<form id='#{title}' action='/form/#{title}' method='POST'>#{content}#{tools}</form>"
        doc = Nokogiri::HTML::DocumentFragment.parse(form)
        doc.css('p').each do |p|
          if p.text =~ /^(\w*) ?(?:->)? ?([^\*]*)? ?(\*?)= ?(.*)?$/
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
      str << "<label for='#{id}'>#{name}</label>"
      case rhs
      when /^\[\s+(\d*)\]$$/             # value = [    5]                                    (textarea)
        str << form_element_textarea(id, code, $1)
      when /^___+(?:\[(\d+)\])?$/        # value = ___[50]                                    (text)
        str << form_element_text(id, code, $1)
      when /^\(x?\)/                     # value = (x) option one () opt2 () opt3 -> option 3 (radio)
        str << form_element_radio(id, code, rhs.scan(/\((x?)\)\s*([^()]+)\s*/))
      when /^\[x?\]/                     # value = [x] option one [] opt2 [] opt3 -> option 3 (checkboxes)
        str << form_element_checkboxes(id, code, rhs.scan(/\[(x?)\] ?([^\[\]]+)/))
      when /^\{(.*)\}$/                  # value = {BOS, SFO, (NYC)}                          (select shorthand)
        str << form_element_select(id, code, rhs.scan(/\(?\w+\)?/))
      when /^\{$/                        # value = {                                          (select)
        str << form_element_select_multiline(id, code, text)
      when ''                            # value =                                            (radio/checkbox list)
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
        when /^   +(\w+) -> (.+),?$/             # NYC -> New, York City
          str << "<option value='#{$1}'>#{$2}</option>"
        when /^   +\((.+)[^,],?$/                # (Boston)
          str << "<option value='#{$1}' selected>#{$1}</option>"
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
        when /\((x?)\)\s*(\w+)\s*(?:->\s*(.*)?)?/
          checked = $1.empty? ? '': "checked='checked'"
          type  = 'radio'
          value = $2
          label = $3 || $2
        when /\[(x?)\]\s*(\w+)\s*(?:->\s*(.*)?)?/
          checked = $1.empty? ? '': "checked='checked'"
          type  = 'checkbox'
          value = $2
          label = $3 || $2
        end

        str << '<li>'
        str << form_element_check_or_radio(type, id, code, value, label, checked)
        str << '</li>'
      end
      str << '</ul>'
    end

    def form_element_check_or_radio_set(type, id, code, items)
      str = ''
      items.each do |item|
        checked = item[0].empty? ? '': "checked='checked'"

        if item[1] =~ /^(\w*) -> (.*)$/
          value = $1
          label = $2
        else
          value = label = item[1]
        end

        str << form_element_check_or_radio(type, id, code, value, label, checked)
      end
      str
    end

    def form_element_check_or_radio(type, id, code, value, label, checked)
      # yes, value and id are conflated, because this is the id of the parent widget

      name = (type == 'checkbox') ? "#{code}[]" : code
      str  =  "<input type='#{type}' name='#{name}' id='#{id}_#{value}' value='#{value}' #{checked} />"
      str << "<label for='#{id}_#{value}'>#{label}</label>"
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
      paths = path.split('/')
      paths.pop
      path = paths.join('/')
      replacement_prefix = opts[:static] ?
        ( opts[:pdf] ? %(img src="file://#{settings.pres_dir}/#{path}) : %(img src="./file/#{path}) ) :
        %(img src="#{@asset_path}image/#{path})
      slide.gsub(/img src=[\"\'](?!https?:\/\/)([^\/].*?)[\"\']/) do |s|
        img_path = File.join(path, $1)
        w, h     = get_image_size(img_path)
        src      = %(#{replacement_prefix}/#{$1}")
        if w && h
          src << %( width="#{w}" height="#{h}")
        end
        src
      end
    end

    if defined?(Magick)
      def get_image_size(path)
        if !cached_image_size.key?(path)
          img = Magick::Image.ping(path).first
          # don't set a size for svgs so they can expand to fit their container
          if img.mime_type == 'image/svg+xml'
            cached_image_size[path] = [nil, nil]
          else
            cached_image_size[path] = [img.columns, img.rows]
          end
        end
        cached_image_size[path]
      end
    else
      def get_image_size(path)
      end
    end

    def update_commandline_code(slide)
      html = Nokogiri::HTML::DocumentFragment.parse(slide)
      parser = CommandlineParser.new

      html.css('pre').each do |pre|
        pre.css('code').each do |code|
          out = code.text
          lines = out.split("\n")
          if lines.first.strip[0, 3] == '@@@'
            lang = lines.shift.gsub('@@@', '').strip
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

    def get_slides_html(opts={:static=>false, :pdf=>false, :toc=>false, :supplemental=>nil})
      @slide_count   = 0
      @section_major = 0
      @section_minor = 0
      @section_title = settings.showoff_config['name']

      sections = ShowOffUtils.showoff_sections(settings.pres_dir, @logger)
      files = []
      if sections
        data = ''
        sections.each do |section|
          if section =~ /^#/
            name = section.each_line.first.gsub(/^#*/,'').strip
            data << process_markdown(name, "<!SLIDE subsection>\n" + section, opts)
          else
            files = []
            files << load_section_files(section)
            files = files.flatten
            files = files.select { |f| f =~ /.md$/ }
            files.each do |f|
              fname = f.gsub(settings.pres_dir + '/', '').gsub('.md', '')
              begin
                data << process_markdown(fname, File.read(f), opts)
              rescue Errno::ENOENT => e
                logger.error e.message
                data << process_markdown(fname, "!SLIDE\n# Missing File!\n## #{fname}", opts)
              end
            end
          end
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

        @asset_path = "./"
      end

      # Display favicon in the window if configured
      @favicon  = settings.showoff_config['favicon']

      # Check to see if the presentation has enabled feedback
      @feedback = settings.showoff_config['feedback'] unless (params && params[:feedback] == 'false')

      # Provide a button in the sidebar for interactive editing if configured
      @edit     = settings.showoff_config['edit'] if @review

      erb :index
    end

    def presenter
      @issues    = settings.showoff_config['issues']
      @edit      = settings.showoff_config['edit'] if @review
      @@cookie ||= guid()
      response.set_cookie('presenter', @@cookie)
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

    def slides(static=false)
      get_slides_html(:static=>static)
    end

    def onepage(static=false)
      @slides = get_slides_html(:static=>static, :toc=>true)
      @favicon = settings.showoff_config['favicon']

      erb :onepage
    end

    def print(static=false)
      @slides = get_slides_html(:static=>static, :toc=>true, :print=>true)
      @favicon = settings.showoff_config['favicon']
      erb :onepage
    end

    def supplemental(content, static=false)
      @slides = get_slides_html(:static=>static, :supplemental=>content)
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

    def stats()
      if request.env['REMOTE_HOST'] == 'localhost'
        # the presenter should have full stats
        @counter = @@counter
      end

      @all = Hash.new
      @@counter.each do |slide, stats|
        @all[slide] = 0
        stats.map do |host, visits|
          visits.each { |entry| @all[slide] += entry['elapsed'].to_f }
        end
      end

      # most and least five viewed slides
      @least = @all.sort_by {|slide, time| time}[0..4]
      @most = @all.sort_by {|slide, time| -time}[0..4]

      erb :stats
    end

    def pdf(static=true)
      @slides = get_slides_html(:static=>static, :pdf=>true)
      @inline = true

      html = erb :onepage
      # TODO make a random filename

      # Process inline css and js for included images
      # The css uses relative paths for images and we prepend the file url
      html.gsub!(/url\([\"\']?(?!https?:\/\/)(.*?)[\"\']?\)/) do |s|
        "url(file://#{settings.pres_dir}/#{$1})"
      end

      # Todo fix javascript path

      # PDFKit.new takes the HTML and any options for wkhtmltopdf
      # run `wkhtmltopdf --extended-help` for a full list of options
      kit = PDFKit.new(html, ShowOffUtils.showoff_pdf_options(settings.pres_dir))

      # Save the PDF to a file
      file = kit.to_file('/tmp/preso.pdf')
    end

  end


   def self.do_static(args)
      args ||= [] # handle nil arguments
      what   = args[0] || "index"
      opt    = args[1]

      # Sinatra now aliases new to new!
      # https://github.com/sinatra/sinatra/blob/v1.3.3/lib/sinatra/base.rb#L1369
      showoff = ShowOff.new!

      name = showoff.instance_variable_get(:@pres_name)
      path = showoff.instance_variable_get(:@root_path)
      logger = showoff.instance_variable_get(:@logger)

      if what == 'supplemental'
        data = showoff.send(what, opt, true)
      else
        data = showoff.send(what, true)
      end

      if data.is_a?(File)
        FileUtils.cp(data.path, "#{name}.pdf")
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
        Dir.glob("#{pres_dir}/*.{css,js}").each { |path|
          FileUtils.copy(path, File.join(file_dir, File.basename(path)))
        }

        # ... and copy all needed image files
        [/img src=[\"\'].\/file\/(.*?)[\"\']/, /style=[\"\']background: url\(\'file\/(.*?)'/].each do |regex|
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
        Dir.glob("#{pres_dir}/*.css").each do |css_path|
          File.open(css_path) do |file|
            data = file.read
            data.scan(/url\([\"\']?(?!https?:\/\/)(.*?)[\"\']?\)/).flatten.each do |path|
              path.gsub!(/(\#.*)$/, '') # get rid of the anchor
              path.gsub!(/(\?.*)$/, '') # get rid of the query
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

   def eval_ruby code
     eval(code).to_s
   rescue => e
     e.message
   end

  # Basic auth boilerplate
  def protected!
    unless authorized?
      response['WWW-Authenticate'] = %(Basic realm="#{@title}: Protected Area")
      throw(:halt, [401, "Not authorized\n"])
    end
  end

  def authorized?
    if not settings.showoff_config.has_key? 'password'
      # if no password is set, then default to allowing access to localhost
      request.env['REMOTE_HOST'] == 'localhost' or request.ip == '127.0.0.1'
    else
      auth   ||= Rack::Auth::Basic::Request.new(request.env)
      user     = settings.showoff_config['user'] || ''
      password = settings.showoff_config['password']
      auth.provided? && auth.basic? && auth.credentials && auth.credentials == [user, password]
    end
  end

  def guid
    # this is a terrifyingly simple GUID generator
    (0..15).to_a.map{|a| rand(16).to_s(16)}.join
  end

  def valid_cookie
    (request.cookies['presenter'] == @@cookie)
  end

  post '/form/:id' do |id|
    @logger.warn("Saving form answers from ip:#{request.ip} for id:##{id}")

    form = params.reject { |k,v| ['splat', 'captures', 'id'].include? k }

    # make sure we've got a bucket for this form, then save our answers
    @@forms[id] ||= {}
    @@forms[id][request.ip] = form

    form.to_json
  end

  # Return a list of the totals for each alternative for each question of a form
  get '/form/:id' do |id|
    return nil unless @@forms.has_key? id

    @@forms[id].each_with_object({}) do |(ip,form), sum|
      form.each do |key, val|
        sum[key]      ||= {}

        if val.class == Array
          val.each do |item|
            sum[key][item] ||= 0
            sum[key][item]  += 1
          end
        else
          sum[key][val] ||= 0
          sum[key][val]  += 1
        end
      end
    end.to_json
  end

  get '/eval_ruby' do
    return eval_ruby(params[:code]) if ENV['SHOWOFF_EVAL_RUBY']

    return "Ruby Evaluation is off. To turn it on set ENV['SHOWOFF_EVAL_RUBY']"
  end

  # provide a callback to trigger a local file editor, but only when called when viewing from localhost.
  get '/edit/*' do |path|
    # Docs suggest that old versions of Sinatra might provide an array here, so just make sure.
    filename = path.class == Array ? path.first : path
    @logger.debug "Editing #{filename}"
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
    if !request.websocket?
      raise Sinatra::NotFound
    else
      request.websocket do |ws|
        ws.onopen do
          ws.send( { 'current' => @@current[:number] }.to_json )
          settings.sockets << ws

          @logger.warn "Open sockets: #{settings.sockets.size}"
        end
        ws.onmessage do |data|
          begin
            control = JSON.parse(data)

            @logger.warn "#{control.inspect}"

            case control['message']
            when 'update'
              # websockets don't use the same auth standards
              # we use a session cookie to identify the presenter
              if valid_cookie()
                name  = control['name']
                slide = control['slide'].to_i

                # check to see if we need to enable a download link
                if @@downloads.has_key?(slide)
                  @logger.debug "Enabling file download for slide #{name}"
                  @@downloads[slide][0] = true
                end

                # update the current slide pointer
                @logger.debug "Updated current slide to #{name}"
                @@current = { :name => name, :number => slide }

                # schedule a notification for all clients
                EM.next_tick { settings.sockets.each{|s| s.send({ 'current' => @@current[:number] }.to_json) } }
              end

            when 'register'
              # save a list of presenters
              if valid_cookie()
                remote = request.env['REMOTE_HOST'] || request.env['REMOTE_ADDR']
                settings.presenters << ws
                @logger.warn "Registered new presenter: #{remote}"
              end

            when 'track'
              remote = request.env['REMOTE_HOST'] || request.env['REMOTE_ADDR']
              slide  = control['slide']
              time   = control['time'].to_f

              @logger.debug "Logged #{time} on slide #{slide} for #{remote}"

              # a bucket for this slide
              @@counter[slide] ||= Hash.new
              # a bucket of slideviews for this address
              @@counter[slide][remote] ||= Array.new
              # and add this slide viewing to the bucket
              @@counter[slide][remote] << { 'elapsed' => time, 'timestamp' => Time.now.to_i, 'presenter' => @@current[:name] }

            when 'position'
              ws.send( { 'current' => @@current[:number] }.to_json ) unless @@cookie.nil?

            when 'pace', 'question'
              # just forward to the presenter(s) along with a debounce in case a presenter is registered twice
              control['id'] = guid()
              EM.next_tick { settings.presenters.each{|s| s.send(control.to_json) } }

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
    @title = ShowOffUtils.showoff_title(settings.pres_dir)
    @pause_msg = ShowOffUtils.pause_msg
    what = params[:captures].first
    opt  = params[:captures][1]
    what = 'index' if "" == what

    if settings.showoff_config.has_key? 'protected'
      protected! if settings.showoff_config['protected'].include? what
    end

    @asset_path = env['SCRIPT_NAME'] == '' ? nil : env['SCRIPT_NAME'].gsub(/^\/?/, '/').gsub(/\/?$/, '/')

    begin
      if (what != "favicon.ico")
        if what == 'supplemental'
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
      raise Sinatra::NotFound
    end
  end

  not_found do
    # Why does the asset path start from cwd??
    @asset_path.slice!(/^./)
    @env = request.env
    erb :'404'
  end

  at_exit do
    ShowOff.flush
  end

end
