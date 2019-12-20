# Adds variable interpolation to the compiler
class Showoff::Compiler
  #
  #
  # @param content [String]
  #     A string of Markdown content which may contain Showoff variables.
  # @return [String]
  #     The content with variables interpolated.
  # @note
  #     Had side effects of altering state datastore.
  # @see
  #     https://github.com/puppetlabs/showoff/blob/3f43754c84f97be4284bb34f9bc7c42175d45226/lib/showoff.rb#L557-L614
  def interpolateVariables(content)
    # update counters, incrementing section:minor if needed
    result = content.gsub("~~~CURRENT_SLIDE~~~", Showoff::State.get(:slide_count).to_s)
    result.gsub!("~~~SECTION:MAJOR~~~", Showoff::State.get(:section_major).to_s)
    if result.include? "~~~SECTION:MINOR~~~"
      Showoff::State.increment(:section_minor)
      result.gsub!("~~~SECTION:MINOR~~~", Showoff::State.get(:section_minor).to_s)
    end

    # scan for pagebreak tags. Should really only be used for handout notes or supplemental materials
    result.gsub!("~~~PAGEBREAK~~~", '<div class="pagebreak">continued...</div>')

    # replace with form rendering placeholder
    result.gsub!(/~~~FORM:([^~]*)~~~/, '<div class="form wrapper" title="\1"></div>')

    # Now check for any kind of options
    content.scan(/(~~~CONFIG:(.*?)~~~)/).each do |match|
      parts = match[1].split('.') # Use dots ('.') to separate Hash keys
      value = Showoff::Config.get(*parts)

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
      file = File.read(File.join(Showoff::Config.root, '_files', name)) rescue "Nonexistent file: #{name}"
      file = "Empty file: #{name}" if file.empty?
      file = HTMLEntities.new.encode(file) rescue "HTML encoding of #{name} failed"

      result.gsub!(match[0], "<pre class=\"highlight\"><code class=\"#{css}\">#{file}</code></pre>")
    end

    result.gsub!(/\[(fa\w?)-(\S*)\]/, '<i class="\1 fa-\2"></i>')

    # For fenced code blocks, translate the space separated classes into one
    # colon separated string so Commonmarker doesn't ignore the rest
    result.gsub!(/^`{3} *(.+)$/) {|s| "``` #{$1.split.join(':')}"}

    result
  end
end
