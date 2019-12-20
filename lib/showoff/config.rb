require 'json'

class Showoff::Config

  def self.keys
    @@config.keys
  end

  # Retrieve settings from the config hash.
  # If multiple arguments are given then it will dig down through data
  # structures argument by argument.
  #
  # Returns the data type & value requested, nil on error.
  def self.get(*setting)
    @@config.dig(*setting) rescue nil
  end

  def self.sections
    @@sections
  end

  # Absolute root of presentation
  def self.root
    @@root
  end

  # Relative path to an item in the presentation directory structure
  def self.path(path)
    File.expand_path(File.join(@@root, path)).sub(/^#{@@root}\//, '')
  end

  # Identifies whether we're including a given notes section
  #
  # @param section [String] The name of the notes section of interest.
  # @return [Boolean] Whether to include this section in the output
  def self.includeSection?(section)
    return true # todo make this work
  end

  def self.load(root, path)
    @@root     = File.expand_path(root)
    @@config   = JSON.parse(File.read(File.join(@@root, path)))
    @@sections = self.expand_sections

    self.load_defaults!
  end

  # Expand and normalize all the different variations that the sections structure
  # can exist in. When finished, this should return an ordered hash of one or more
  # section titles pointing to an array of filenames, for example:
  #
  # {
  #     "Section name": [ "array.md, "of.md, "files.md"],
  #     "Another Section": [ "two/array.md, "two/of.md, "two/files.md"],
  # }
  #
  # See valid input forms at
  #   https://puppetlabs.github.io/showoff/documentation/PRESENTATION_rdoc.html#label-Defining+slides+using+the+sections+setting.
  # Source:
  #  https://github.com/puppetlabs/showoff/blob/3f43754c84f97be4284bb34f9bc7c42175d45226/lib/showoff_utils.rb#L427-L475
  def self.expand_sections
    begin
      if @@config.is_a?(Hash)
        # dup so we don't overwrite the original data structure and make it impossible to re-localize
        sections = @@config['sections'].dup
      else
        sections = @@config.dup
      end

      if sections.is_a? Array
        sections = self.legacy_sections(sections)
      elsif sections.is_a? Hash
        raise "Named sections are unsupported on Ruby versions less than 1.9." if RUBY_VERSION.start_with? '1.8'
        sections.each do |key, value|
          next if value.is_a? Array
          path = File.dirname(value)
          data = JSON.parse(File.read(File.join(@@root, value)))
          raise "The section file #{value} must contain an array of filenames." unless data.is_a? Array

          # get relative paths to each slide in the array
          sections[key] = data.map do |filename|
            self.path(filename)
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

  # Source:
  #  https://github.com/puppetlabs/showoff/blob/3f43754c84f97be4284bb34f9bc7c42175d45226/lib/showoff_utils.rb#L477-L545
  def self.legacy_sections(data)
    # each entry in sections can be:
    # - "filename.md"
    # - { "section": "filename.md" }
    # - { "section": "directory" }
    # - { "section": [ "array.md, "of.md, "files.md"] }
    # - { "include": "sections.json" }
    sections = {}
    counters = {}
    lastpath = nil

    data.map do |entry|
      next entry if entry.is_a? String
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
    end.flatten.compact.each do |entry|
      # We do this in two passes simply because most of it was already done
      # and I don't want to waste time on legacy functionality.

      # Normalize to a proper path from presentation root
      filename = self.path(entry)
      # and then strip out the locale directory, if there is one
      filename.sub!(/^(locales\/[\w-]+\/)/, '')
      locale = $1

      if File.directory? filename
        path = entry
        sections[path] ||= []
        Dir.glob("#{filename}/**/*.md").sort.each do |slidefile|
          fullpath = locale.nil? ? slidefile : "#{locale}/#{slidefile}"
          sections[path] << fullpath
        end
      else
        path = File.dirname(entry)

        # this lastpath business allows us to reference files in a directory that aren't
        # necessarily contiguous.
        if path != lastpath
          counters[path] ||= 0
          counters[path]  += 1
        end

        # now record the last path we've seen
        lastpath = path

        # and if there are more than one disparate occurences of path, add a counter to this string
        path = "#{path} (#{counters[path]})" unless counters[path] == 1

        sections[path] ||= []
        sections[path]  << filename
      end
    end

    sections
  end

  def self.load_defaults!
    # use a symbol which cannot clash with a string key loaded from json
    renderer = @@config['markdown'] || :autodetected
    defaults = case renderer
      when 'rdiscount'
        {
          :autolink          => true,
        }
      when 'maruku'
        {
          :use_tex           => false,
          :png_dir           => 'images',
          :html_png_url      => '/file/images/',
        }
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
          :escape_html       => false,
        }
      end

    @@config[renderer] ||= {}
    @@config[renderer]   = defaults.merge!(@@config[renderer])
  end

end
