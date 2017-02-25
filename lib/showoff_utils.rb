class ShowOffUtils

  # Helper method to parse a comma separated options string and stores
  # the result in a dictionrary
  #
  # Example:
  #
  #    "tpl=hpi,title=Over the rainbow"
  #
  #    will be stored as
  #
  #      { "tpl" => "hpi", "title" => "Over the rainbow" }
  def self.parse_options(option_string="")
    result = {}

    if option_string
      option_string.split(",").each do |element|
        pair = element.split("=")
        result[pair[0]] = pair.size > 1 ? pair[1] : nil
      end
    end

    result
  end

  def self.presentation_config_file
    @presentation_config_file ||= 'showoff.json'
  end

  def self.presentation_config_file=(filename)
    @presentation_config_file = filename
  end

  def self.create(dirname,create_samples,dirs='one')
    FileUtils.mkdir_p(dirname)
    Dir.chdir(dirname) do
      dirs = dirs.split(',')

      if create_samples
        dirs.each do |dir|
          # create section
          FileUtils.mkdir_p(dir)

          # create markdown file
          File.open("#{dir}/00_section.md", 'w+') do |f|
            f.puts make_slide("Section Header", "center subsection")
          end
          File.open("#{dir}/01_slide.md", 'w+') do |f|
            f.puts make_slide("My Presentation")
          end
          File.open("#{dir}/02_slide.md", 'w+') do |f|
            f.puts make_slide("Bullet Points","bullets incremental",["first point","second point","third point"])
          end
        end
      end

      # Create asset directories
      FileUtils.mkdir_p('_files/share')
      FileUtils.mkdir_p('_images')

      # create showoff.json
      File.open(ShowOffUtils.presentation_config_file, 'w+') do |f|
        sections = dirs.collect {|dir| {"section" => dir} }
        f.puts JSON.pretty_generate({ "name" => "My Preso", "sections" => sections })
      end
    end
  end

  def self.skeleton(config)
    if config
      FileUtils.cp(config, '.')
      ShowOffUtils.presentation_config_file = File.basename(config)
    end

    # Create asset directories
    FileUtils.mkdir_p('_files/share')
    FileUtils.mkdir_p('_images')

    self.showoff_slide_files('.').each do |filename|
      next if File.exist? filename

      puts "Creating: #{filename}"
      if filename.downcase.end_with? '.md'
        FileUtils.mkdir_p File.dirname(filename)

        File.open(filename, 'w+') do |f|
          if filename =~ /section/i
            # kind of looks like a section slide
            f.puts make_slide("#{filename.sub(/\.md$/, '')}", "center subsection")
          else
            f.puts make_slide("#{filename.sub(/\.md$/, '')}")
          end
        end
      else
        FileUtils.mkdir_p filename
      end
    end
  end

  def self.validate(config)
    showoff    = ShowOff.new!(:pres_file  => config)
    validators = showoff.settings.showoff_config['validators'] || {}
    files      = []
    errors     = []

    # get a list of actual filenames
    files = self.showoff_slide_files('.')
    files.each do |filename|
      unless File.exist? filename
        errors << "Missing path: #{filename}"
        next
      end

      if filename.downcase.end_with? '.md'
        print '.'
        showoff.get_code_from_slide(filename.sub('.md',''), 'all', false).each_with_index do |block, index|
          lang, code, classes = block
          validator = validators[lang]

          if classes.include? 'no-validate'
            print '-'
            next

          elsif validator
            # write out a tempfile because many validators require files to work with
            Tempfile.open('showoff-validation') do |f|
              File.write(f.path, code)
              unless system("#{validator} #{f.path}", :out => File::NULL, :err => File::NULL)
                print 'F'
                errors << "Invalid #{lang} code on #{filename} [#{index}]"
              end
            end
          end

       end
      end
    end

    puts
    puts "Found #{errors.size} errors."
    unless errors.empty?
      errors.each { |err| puts " * #{err}" }
      exit!
    end
  end

  HEROKU_PROCFILE    = 'Procfile'
  HEROKU_GEMS_FILE   = 'Gemfile'
  HEROKU_CONFIG_FILE = 'config.ru'

	# Setup presentation to run on Heroku
  #
  # name         - String containing heroku name
  # force        - boolean if .gems/Gemfile and config.ru should be overwritten if they don't exist
  # password     - String containing password to protect your heroku site; nil means no password protection
  def self.heroku(name, force = false, password = nil)
    modified_something = create_gems_file(HEROKU_GEMS_FILE,
                                          !password.nil?,
                                          force,
                                          lambda{ |gem| "gem '#{gem}'" },
                                          lambda{ "source :rubygems" })

    create_file_if_needed(HEROKU_PROCFILE,force) do |file|
      modified_something = true
      file.puts 'bundle exec thin start -R config.ru -e production -p $PORT'
    end

    create_file_if_needed(HEROKU_CONFIG_FILE,force) do |file|
      modified_something = true
      file.puts 'require "showoff"'
      file.puts 'require "showoff/version"'
      if password.nil?
        file.puts 'run ShowOff.new'
      else
        file.puts 'require "rack"'
        file.puts 'showoff_app = ShowOff.new'
        file.puts 'protected_showoff = Rack::Auth::Basic.new(showoff_app) do |username, password|'
        file.puts	"\tpassword == '#{password}'"
        file.puts 'end'
        file.puts 'run protected_showoff'
      end
    end

    modified_something
  end

  # generate a static version of the site into the gh-pages branch
  def self.github
    ShowOff.do_static(nil)
    FileUtils.touch 'static/.nojekyll'
    `git add -f static`
    sha = `git write-tree`.chomp
    tree_sha = `git rev-parse #{sha}:static`.chomp
    `git read-tree HEAD`  # reset staging to last-commit
    ghp_sha = `git rev-parse gh-pages 2>/dev/null`.chomp
    extra = ghp_sha != 'gh-pages' ? "-p #{ghp_sha}" : ''
    commit_sha = `echo 'static presentation' | git commit-tree #{tree_sha} #{extra}`.chomp
    `git update-ref refs/heads/gh-pages #{commit_sha}`
  end

  # clone a repo url, then run a provided block
  def self.clone(url, branch=nil, path=nil)
    require 'tmpdir'
    Dir.mktmpdir do |dir|
      if branch
        system('git', 'clone', '-b', branch, '--single-branch', '--depth', '1', url, dir)
      else
        system('git', 'clone', '--depth', '1', url, dir)
      end

      dir = File.join(dir, path) if path
      Dir.chdir dir do
        yield if block_given?
      end
    end
  end

  # just update the repo in cwd
  def self.update(verbose=false)
    puts "Updating presentation repository..." if verbose
    system('git', 'pull')
  end


  # Makes a slide as a string.
  # [title] title of the slide
  # [classes] any "classes" to include, such as 'smaller', 'transition', etc.
  # [content] slide content.  Currently, if this is an array, it will make a bullet list.  Otherwise
  #           the string value of this will be put in the slide as-is
  def self.make_slide(title,classes="",content=nil)
    slide = "<!SLIDE #{classes}>\n"
    slide << "# #{title}\n"
    slide << "\n"
    if content
      if content.kind_of? Array
        content.each { |x| slide << "* #{x.to_s}\n" }
      else
        slide << content.to_s
      end
    end
    slide
  end

  TYPES = {
    :default      => lambda { |t,size,source,type| make_slide(t,"#{size} #{type}",source) },
    'title'       => lambda { |t,size,dontcare|    make_slide(t,size) },
    'bullets'     => lambda { |t,size,dontcare|    make_slide(t,"#{size} bullets incremental",["bullets","go","here"])},
    'smbullets'   => lambda { |t,size,dontcare|    make_slide(t,"#{size} smbullets incremental",["bullets","go","here","and","here"])},
    'code'        => lambda { |t,size,src|         make_slide(t,size,blank?(src) ? "    @@@ Ruby\n    code_here()" : src) },
    'commandline' => lambda { |t,size,dontcare|    make_slide(t,"#{size} commandline","    $ command here\n    output here")},
    'full-page'   => lambda { |t,size,dontcare|    make_slide(t,"#{size} full-page","![Image Description](image/ref.png)")},
  }


  # Adds a new slide to a given dir, giving it a number such that it falls after all slides
  # in that dir.
  # Options are:
  # [:dir] - dir where we put the slide (if omitted, slide is output to $stdout)
  # [:name] - name of the file, without the number prefix. (if omitted, a default is used)
  # [:title] - title in the slide.  If not specified the source file name is
  #            used.  If THAT is not specified, uses the value of +:name+.  If THAT is not
  #            specified, a suitable default is used
  # [:code] - path to a source file to use as content (force :type to be 'code')
  # [:number] - true if numbering should be done, false if not
  # [:type] - the type of slide to create
  def self.add_slide(options)

    add_new_dir(options[:dir]) if options[:dir] && !File.exist?(options[:dir])

    options[:type] = 'code' if options[:code]

    title = determine_title(options[:title],options[:name],options[:code])

    options[:name] = 'new_slide' if !options[:name]

    size,source = determine_size_and_source(options[:code])
    type = options[:type] || :default
    slide = TYPES[type].call(title,size,source)

    if options[:name]
      filename = determine_filename(options[:dir],options[:name],options[:number])
      write_file(filename,slide)
    else
      puts slide
      puts
    end

  end

  # Adds the given directory to this presentation, appending it to
  # the end of showoff.json as well
  def self.add_new_dir(dir)
    puts "Creating #{dir}..."
    Dir.mkdir dir

    showoff_json = JSON.parse(File.read(ShowOffUtils.presentation_config_file))
    showoff_json["section"] = dir
    File.open(ShowOffUtils.presentation_config_file,'w') do |file|
      file.puts JSON.generate(showoff_json)
    end
    puts "#{ShowOffUtils.presentation_config_file} updated"
  end

  def self.blank?(string)
    string.nil? || string.strip.length == 0
  end

  def self.determine_size_and_source(code)
    size = ""
    source = ""
    if code
      source,lines,width = read_code(code)
      size = adjust_size(lines,width)
    end
    [size,source]
  end

  def self.write_file(filename,slide)
    File.open(filename,'w') do |file|
      file.puts slide
    end
    puts "Wrote #{filename}"
  end

  def self.determine_filename(slide_dir,slide_name,number)
    raise "Slide name is required" unless slide_name

    if number
      next_num   = find_next_number(slide_dir)
      slide_name = "#{next_num}_#{slide_name}"
    end

    if slide_dir
      filename = "#{slide_dir}/#{slide_name}.md"
    else
      filename = "#{slide_name}.md"
    end

    filename
  end

  # Finds the next number in the given dir to
  # name a slide as the last slide in the dir.
  def self.find_next_number(slide_dir)
    slide_dir ||= '.'
    max = Dir.glob("#{slide_dir}/*.md").collect do |f|
      next unless f =~ /^#{slide_dir}\/(\d+)/
      $1.to_i
    end.compact.max || 0

    sprintf("%02d", max+1)
  end

  def self.determine_title(title,slide_name,code)
    if blank?(title)
      title = slide_name
      title = File.basename(code) if code
    end
    title = "Title here" if blank?(title)
    title
  end

  # Determines a more optimal value for the size (e.g. small vs. smaller)
  # based upon the size of the code being formatted.
  def self.adjust_size(lines,width)
    size = ""
    # These values determined empircally
    size = "small" if width > 50
    size = "small" if lines > 15
    size = "smaller" if width > 57
    size = "smaller" if lines > 19
    puts "WARNING: some lines are too long and might be truncated" if width > 65
    puts "WARNING: your code is too long and may not fit on a slide" if lines > 23
    size
  end

  # Reads the code from the source file, returning
  # the code, indented for markdown, as well as the number of lines
  # and the width of the largest line
  def self.read_code(source_file)
    code = "    @@@ #{lang(source_file)}\n"
    lines = 0
    width = 0
    File.open(source_file) do |code_file|
      code_file.readlines.each do |line|
        code += "    #{line}"
        lines += 1
        width = line.length if line.length > width
      end
    end
    [code,lines,width]
  end

  def self.showoff_sections(dir, logger = nil)
    unless logger
      logger = Logger.new(STDOUT)
      logger.level = Logger::WARN
    end

    index = File.join(dir, ShowOffUtils.presentation_config_file)
    begin
      data = JSON.parse(File.read(index)) rescue ["."] # default boring showoff.json
      logger.debug data
      if data.is_a?(Hash)
        sections = data['sections'] if data.include? 'sections'
      else
        sections = data
      end

      if sections.is_a? Array
        sections = showoff_legacy_sections(sections)
      elsif sections.is_a? Hash
        sections.each do |key, value|
          next if value.is_a? Array
          cwd  = File.expand_path(dir)
          path = File.dirname(value)
          data = JSON.parse(File.read(value))
          raise "The section file #{value} must contain an array of filenames." unless data.is_a? Array

          # get relative paths to each slide in the array
          sections[key] = data.map do |filename|
            File.expand_path("#{path}/#{filename}").sub(/^#{cwd}\//, '')
          end
        end
      else
        raise "The `sections` key must be an Array or Hash, not a #{sections.class}."
      end

    rescue => e
      logger.error "There was a problem with the presentation file #{index}"
      logger.error e.message
      logger.debug e.backtrace
      sections = {}
    end

    sections
  end

  def self.showoff_legacy_sections(data)
    # each entry in sections can be:
    # - "filename.md"
    # - { "section": "filename.md" }
    # - { "section": [ "array.md, "of.md, "files.md"] }
    # - { "include": "sections.json" }
    sections = {}
    data.map do |entry|
      if entry.is_a? String
        if File.directory? entry
          next Dir.glob("#{entry}/**/*.md").sort
        else
          next entry
        end
      end
      next nil unless entry.is_a? Hash
      next entry['section'] if entry.include? 'section'

      section = nil
      if entry.include? 'include'
        file = entry['include']
        path = File.dirname(file)
        data = JSON.parse(File.read(file))
        if data.is_a? Array
          if path == '.'
            section = data
          else
            section = data.map do |source|
              "#{path}/#{source}"
            end
          end
        end
      end

      section
    end.flatten.compact.each do |filename|
      # We do this in two passes simply because most of it was already done
      # and I don't want to waste time on legacy functionality.
      path = File.dirname(filename)

      sections[path] ||= []
      sections[path]  << filename
    end
    sections
  end

  def self.showoff_slide_files(dir, logger = nil)
    data = showoff_sections(dir, logger)
    data.map { |key, value| value }.flatten
  end

  def self.showoff_title(dir = '.')
    get_config_option(dir, 'name', "Presentation")
  end

  def self.pause_msg(dir = '.')
    get_config_option(dir, 'pause_msg', 'PAUSED')
  end

  def self.default_style(dir = '.')
    get_config_option(dir, 'style', '')
  end

  def self.default_style?(style, dir = '.')
    default = default_style(dir)
    style.split('/').last.sub(/\.css$/, '') == default
  end

  def self.showoff_pdf_options(dir = '.')
    opts = get_config_option(dir, 'pdf_options', {:page_size => 'Letter', :orientation => 'Landscape'})
    Hash[opts.map {|k, v| [k.to_sym, v]}] # keys must be symbols
  end

  def self.showoff_markdown(dir = ".")
    get_config_option(dir, "markdown", "redcarpet")
  end

  def self.showoff_renderer_options(dir = '.', default_options = MarkdownConfig::defaults(dir))
    opts = get_config_option(dir, showoff_markdown(dir), default_options)
    Hash[opts.map {|k, v| [k.to_sym, v]}] if opts    # keys must be symbols
  end

  def self.get_config_option(dir, option, default = nil)
    index = File.join(dir, ShowOffUtils.presentation_config_file)
    if File.exist?(index)
      data = JSON.parse(File.read(index))
      if data.is_a?(Hash)
        if default.is_a?(Hash)
          default.merge(data[option] || {})
        else
          data[option] || default
        end
      end
    else
      default
    end
  end

  EXTENSIONS =  {
    'pl' => 'perl',
    'rb' => 'ruby',
    'erl' => 'erlang',
    # so not exhaustive, but probably good enough for now
  }

  def self.lang(source_file)
    ext = File.extname(source_file).gsub(/^\./,'')
    EXTENSIONS[ext] || ext
  end

  REQUIRED_GEMS = %w(redcarpet showoff heroku)

  # Creates the file that lists the gems for heroku
  #
  # filename  - String name of the file
  # password  - Boolean to indicate if we are setting a password
  # force     - Boolean to indicate if we should overwrite the existing file
  # formatter - Proc/lambda that takes 1 argument, the gem name, and formats it for the file
  #             This is so we can support both the old .gems and the new bundler Gemfile
  # header    - Proc/lambda that creates any header information in the file
  #
  # Returns a boolean indicating that we had to create the file or not.
  def self.create_gems_file(filename,password,force,formatter,header=nil)
    create_file_if_needed(filename,force) do |file|
      file.puts header.call unless header.nil?
      REQUIRED_GEMS.each { |gem| file.puts formatter.call(gem) }
      file.puts formatter.call("rack") if password
    end
  end

  # Creates the given filename if it doesn't exist or if force is true
  #
  # filename - String name of the file to create
  # force    - if true, the file will always be created, if false, only create
  #            if it's not there
  # block    - takes a block that will be given the file handle to write
  #            data into the file IF it's being created
  #
  # Examples
  #
  #   create_file_if_needed("config.ru",false) do |file|
  #     file.puts "require 'showoff'"
  #     file.puts "run ShowOff.new"
  #   end
  #
  # Returns true if the file was created
  def self.create_file_if_needed(filename,force)
    if !File.exist?(filename) || force
      File.open(filename, 'w+') do |f|
        yield f
      end
      true
    else
      puts "#{filename} exists; not overwriting (see showoff help heroku)"
      false
    end
  end

  def self.command(command, error='command failed')
    puts "Running '#{command}'..."
    system(command) or raise error
  end
end

# Load the configuration for the markdown engine from the showoff.json
# file
module MarkdownConfig
  def self.setup(dir_name)
    require 'tilt'
    require 'tilt/erb'

    renderer = ShowOffUtils.showoff_markdown(dir_name)
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

        # Load maruku options
        opts = ShowOffUtils.showoff_renderer_options(dir_name,
                                                     { :use_tex      => false,
                                                       :png_dir      => 'images',
                                                       :html_png_url => '/file/images/'})

        if opts[:use_tex]
          MaRuKu::Globals[:html_math_output_mathml] = false
          MaRuKu::Globals[:html_math_output_png]    = true
          MaRuKu::Globals[:html_math_engine]        = 'none'
          MaRuKu::Globals[:html_png_engine] =  'blahtex'
          MaRuKu::Globals[:html_png_dir]    = opts[:png_dir]
          MaRuKu::Globals[:html_png_url]    = opts[:html_png_url]
        end

      when 'bluecloth'
        Tilt.prefer Tilt::BlueClothTemplate, "markdown"

      when 'kramdown'
        Tilt.prefer Tilt::KramdownTemplate, "markdown"

      when 'commonmarker'
        Tilt.prefer Tilt::CommonMarkerTemplate, "markdown"

      else
        Tilt.prefer Tilt::RedcarpetTemplate, "markdown"

      end
    rescue LoadError
      puts "ERROR: The #{renderer} markdown rendering engine does not appear to be installed correctly."
      exit! 1
    end
  end

  def self.defaults(dir_name)
    case ShowOffUtils.showoff_markdown(dir_name)
    when 'rdiscount'
      {
        :autolink          => true,
      }
    when 'maruku'
      {}
    when 'bluecloth'
      {
        :auto_links        => true,
        :definition_lists  => true,
        :superscript       => true,
        :tables            => true,
      }
    when 'kramdown'
      {}
    else
      {
        :autolink          => true,
        :no_intra_emphasis => true,
        :superscript       => true,
        :tables            => true,
        :underline         => true,
      }
    end
  end
end
