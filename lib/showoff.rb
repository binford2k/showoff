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
  $stderr.puts 'WARN: image sizing disabled - install rmagick'
end

begin
  require 'pdfkit'
rescue LoadError
  $stderr.puts 'WARN: pdf generation disabled - install pdfkit'
end

require 'tilt'

class ShowOff < Sinatra::Application

  attr_reader :cached_image_size

  set :views, File.dirname(__FILE__) + '/../views'
  set :public_folder, File.dirname(__FILE__) + '/../public'

  set :server, 'thin'
  set :sockets, []

  set :verbose, false
  set :pres_dir, '.'
  set :pres_file, 'showoff.json'
  set :page_size, "Letter"
  set :pres_template, nil
  set :showoff_config, {}
  set :downloads, nil
  set :counter, nil
  set :current, 0
  set :cookie, nil

  def initialize(app=nil)
    super(app)
    @logger = Logger.new(STDOUT)
    @logger.formatter = proc { |severity,datetime,progname,msg| "#{progname} #{msg}\n" }
    @logger.level = settings.verbose ? Logger::DEBUG : Logger::WARN

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

      # Set options for template and page size
      settings.page_size = showoff_json["page-size"] || "Letter"
      settings.pres_template = showoff_json["templates"]
    end

    @logger.debug settings.pres_template

    @cached_image_size = {}
    @logger.debug settings.pres_dir
    @pres_name = settings.pres_dir.split('/').pop
    require_ruby_files

    # Default asset path
    @asset_path = "./"

    # Track downloadable files
    @@downloads = Hash.new

    # Page view time accumulator
    @@counter = Hash.new

    # The current slide that the presenter is viewing
    @@current = 0

    # Initialize Markdown Configuration
    #MarkdownConfig::setup(settings.pres_dir)
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
      attr_reader :classes, :text, :tpl
      def initialize( context = "")

        @tpl = "default"
        @classes = []

        # Parse the context string for options and content classes
        if context and context.match(/(\[(.*?)\])?(.*)/)

          options = ShowOffUtils.parse_options($2)
          @tpl = options["tpl"] if options["tpl"]
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


    def process_markdown(name, content, opts={:static=>false, :pdf=>false, :toc=>false, :supplemental=>nil})
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

      slides.delete_if {|slide| slide.empty? }

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

        @slide_count += 1
        content_classes = slide.classes

        # extract transition, defaulting to none
        transition = 'none'
        content_classes.delete_if { |x| x =~ /^transition=(.+)/ && transition = $1 }
        # extract id, defaulting to none
        id = nil
        content_classes.delete_if { |x| x =~ /^#([\w-]+)/ && id = $1 }
        id = name unless id
        @logger.debug "id: #{id}" if id
        @logger.debug "classes: #{content_classes.inspect}"
        @logger.debug "transition: #{transition}"
        @logger.debug "tpl: #{slide.tpl} " if slide.tpl


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
        content += " class=\"slide #{classes}\" data-transition=\"#{transition}\">"

        # name the slide. If we've got multiple slides in this file, we'll have a sequence number
        # include that sequence number to index directly into that content
        if seq
          content += "<div class=\"content #{classes}\" ref=\"#{name}/#{seq.to_s}\">\n"
        else
          content += "<div class=\"content #{classes}\" ref=\"#{name}\">\n"
        end

        # Apply the template to the slide and replace the key to generate the content of the slide
        sl = process_content_for_replacements(template.gsub(/~~~CONTENT~~~/, slide.text))
        sl = Tilt[:markdown].new { sl }.render
        sl = update_p_classes(sl)
        sl = process_content_for_section_tags(sl)
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
    def process_content_for_section_tags(content)
      return unless content

      # because this is post markdown rendering, we may need to shift a <p> tag around
      # remove the tags if they're by themselves
      result = content.gsub(/<p>~~~SECTION:([^~]*)~~~<\/p>/, '<div class="\1">')
      result.gsub!(/<p>~~~ENDSECTION~~~<\/p>/, '</div>')

      # shove it around the div if it belongs to the contained element
      result.gsub!(/(<p>)?~~~SECTION:([^~]*)~~~/, '<div class="\2">\1')
      result.gsub!(/~~~ENDSECTION~~~(<\/p>)?/, '\1</div>')

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

        Nokogiri::HTML(content).css('div.subsection > h1').each do |section|
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
      html = Nokogiri::XML.parse(slide)
      parser = CommandlineParser.new

      html.css('pre').each do |pre|
        pre.css('code').each do |code|
          out = code.text
          lines = out.split("\n")
          if lines.first.strip[0, 3] == '@@@'
            lang = lines.shift.gsub('@@@', '').strip
            pre.set_attribute('class', 'sh_' + lang.downcase) if !lang.empty?
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
      html.root.to_s
    end

    def get_slides_html(opts={:static=>false, :pdf=>false, :toc=>false, :supplemental=>nil})
      @slide_count   = 0
      @section_major = 0
      @section_minor = 0

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
              data << process_markdown(fname, File.read(f), opts)
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
        @title = ShowOffUtils.showoff_title
        @slides = get_slides_html(:static=>static)

        @pause_msg = ShowOffUtils.pause_msg

        # Identify which languages to bundle for highlighting
        @languages = @slides.scan(/<pre class=".*(?!sh_sourceCode)(sh_[\w-]+).*"/).uniq.map{ |w| "sh_lang/#{w[0]}.min.js"}

        @asset_path = "./"
      end
      erb :index
    end

    def presenter
      @issues   = settings.showoff_config['issues']
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
      #@languages = @slides.scan(/<pre class=".*(?!sh_sourceCode)(sh_[\w-]+).*"/).uniq.map{ |w| "/sh_lang/#{w[0]}.min.js"}
      erb :onepage
    end

    def supplemental(content, static=false)
      @slides = get_slides_html(:static=>static, :supplemental=>content)
      @wrapper_classes = ['supplemental']
      erb :onepage
    end

    def download()
      begin
        shared = Dir.glob("#{settings.pres_dir}/_files/share/*").map { |path| File.basename(path) }
        # We use the icky -999 magic index because it has to be comparable for the view sort
        @downloads = { -999 => [ true, 'Shared Files', shared ] }
      rescue Errno::ENOENT => e
        # don't fail if the directory doesn't exist
        @downloads = {}
      end
      @downloads.merge! @@downloads
      erb :download
    end

    # Called from the presenter view. Update the current slide.
    def update()
      if authorized?
        slide = request.params['page'].to_i

        # check to see if we need to enable a download link
        if @@downloads.has_key?(slide)
          @logger.debug "Enabling file download for slide #{slide}"
          @@downloads[slide][0] = true
        end

        # update the current slide pointer
        @logger.debug "Updated current slide to #{slide}"
        @@current = slide
      end
    end

    # Called once per second by each client view. Keep track of viewing stats
    # and return the current page the instructor is showing
    def ping()
      slide = request.params['page'].to_i
      remote = request.env['REMOTE_HOST']

      # we only care about tracking viewing time that's not on the current slide
      # (or on the previous slide, since we'll get at least one hit from the follower)
      if slide != @@current and slide != @@current-1
        # a bucket for this slide
        if not @@counter.has_key?(slide)
          @@counter[slide] = Hash.new
        end

        # a counter for this viewer
        if @@counter[slide].has_key?(remote)
          @@counter[slide][remote] += 1
        else
          @@counter[slide][remote] = 1
        end
      end

      # return current slide as a string to the client
      "#{@@current}"
    end

    # Returns the current page the instructor is showing
    def getpage()
      # return current slide as a string to the client
      "#{@@current}"
    end

    def stats()
      if request.env['REMOTE_HOST'] == 'localhost'
        # the presenter should have full stats
        @counter = @@counter
      end

      @all = Hash.new
      @@counter.each do |slide, stats|
        @all[slide] = 0
        stats.map { |host, count| @all[slide] += count }
      end

      # most and least five viewed slides
      @least = @all.sort_by {|slide, time| time}[0..4]
      @most = @all.sort_by {|slide, time| -time}[0..4]

      erb :stats
    end

    def pdf(static=true)
      @slides = get_slides_html(:static=>static, :pdf=>true)
      @inline = true

      # Identify which languages to bundle for highlighting
      @languages = @slides.scan(/<pre class=".*(?!sh_sourceCode)(sh_[\w-]+).*"/).uniq.map{ |w| "/sh_lang/#{w[0]}.min.js"}

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


   def self.do_static(what)
      what = "index" if !what

      # Sinatra now aliases new to new!
      # https://github.com/sinatra/sinatra/blob/v1.3.3/lib/sinatra/base.rb#L1369
      showoff = ShowOff.new!

      name = showoff.instance_variable_get(:@pres_name)
      path = showoff.instance_variable_get(:@root_path)
      logger = showoff.instance_variable_get(:@logger)

      data = showoff.send(what, true)

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
          FileUtils.copy_entry("#{my_path}/#{dir}", "#{out}/#{dir}")
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
        data.scan(/img src=[\"\'].\/file\/(.*?)[\"\']/).flatten.each do |path|
          dir = File.dirname(path)
          FileUtils.makedirs(File.join(file_dir, dir))
          FileUtils.copy(File.join(pres_dir, path), File.join(file_dir, path))
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
              FileUtils.copy(File.join(pres_dir, path), File.join(file_dir, path))
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

  get '/eval_ruby' do
    return eval_ruby(params[:code]) if ENV['SHOWOFF_EVAL_RUBY']

    return "Ruby Evaluation is off. To turn it on set ENV['SHOWOFF_EVAL_RUBY']"
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
          ws.send( { 'current' => @@current }.to_json )
          settings.sockets << ws

          @logger.warn "Open sockets: #{settings.sockets.size}"
        end
        ws.onmessage do |data|
          begin
          control = JSON.parse(data)

          @logger.info "#{control.inspect}"

          case control['message']
          when 'update'
            # websockets don't use the same auth standards
            # we use a session cookie to identify the presenter
            if valid_cookie()
              slide = control['slide'].to_i

              # check to see if we need to enable a download link
              if @@downloads.has_key?(slide)
                @logger.debug "Enabling file download for slide #{slide}"
                @@downloads[slide][0] = true
              end

              # update the current slide pointer
              @logger.debug "Updated current slide to #{slide}"
              @@current = slide

              # schedule a notification for all clients
              EM.next_tick { settings.sockets.each{|s| s.send({ 'current' => @@current }.to_json) } }
            end

          when 'track'
            remote = request.env['REMOTE_HOST'] || request.env['REMOTE_ADDR']
            slide  = control['slide'].to_i
            time   = control['time'].to_f

            @logger.debug "Logged #{time} on slide #{slide} for #{remote}"

            # a bucket for this slide
            @@counter[slide] ||= Hash.new
            # a counter for this viewer
            @@counter[slide][remote] ||= 0
            # and add the elapsed time
            @@counter[slide][remote] += time

          when 'position'
            ws.send( { 'current' => @@current }.to_json )

          when 'feedback'
            slide    = control['slide']
            rating   = control['rating']
            feedback = control['feedback']

            File.open("feedback.json", "w+") do |f|
              data = JSON.load(f) || Hash.new

              data[slide] ||= Array.new
              data[slide] << { :rating => rating, :feedback => feedback }
              f.write data.to_json
            end


          else
            @logger.warn "Unknown message <#{control['message']}> received."
            @logger.warn control.inspect
          end

          rescue Exception => e
            @logger.warn "Hah! Shit blew up: #{e}"
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
    @title = ShowOffUtils.showoff_title
    @pause_msg = ShowOffUtils.pause_msg
    what = params[:captures].first
    opt  = params[:captures][1]
    what = 'index' if "" == what

    if settings.showoff_config.has_key? 'protected'
      protected! if settings.showoff_config['protected'].include? what
    end

    # this hasn't been set to anything remotely interesting for a long time now
    @asset_path = nil

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
    if defined?(@@counter)
      File.open("viewstats.json", "w") do |f|
        f.write @@counter.to_json
      end
    end
  end
end
