require 'erb'

class Showoff::Presentation::Slide
  attr_reader :section, :section_title, :name, :seq, :id, :ref, :background, :transition, :markdown, :classes

  def initialize(options, content, context={})
    @markdown   = content
    @template   = 'default'
    @transition = 'none'
    @classes    = []
    setOptions!(options)
    setContext!(context)
  end

  def render
    content = Showoff::Compiler.new(@options).render(@markdown)

    ERB.new(File.read(File.join('views','slide.erb')), nil, '-').result(binding)
  end

  # options are key=value elements within the [] brackets
  def setOptions!(options)
    return unless options
    return unless matches = options.match(/(\[(.*?)\])?(.*)/)

    if matches[2]
      matches[2].split(",").each do |element|
        key, val = element.split("=")
        case key
        when 'tpl', 'template'
          @template = val
        when 'bg', 'background'
          @background = val
        when 'transition'                 # specified in classes takes priority
          @transition = val
        when 'id'                         # specified in classes takes priority
          @id = val
        else
          $logger.warning "Unknown slide option: #{key}=#{val}"
        end
      end
    end

    if matches[3]
      @classes = matches[3].split
    end
  end

  # currently a mishmash of passed in context and calculated valued extracted from classes
  def setContext!(context)
    @section = context[:section] || 'main'
    @name    = context[:name].chomp('.md')
    @seq     = context[:seq]

    #TODO: this should be in options
    # extract id from classes if set, or default to the HTML sanitized name
    @classes.delete_if { |x| x =~ /^#([\w-]+)/ && @id = $1 }
    @id ||= @name.dup.gsub(/[^-A-Za-z0-9_]/, '_')
    @id << seq.to_s if @seq

    # provide an href for the slide. If we've got multiple slides in this file, we'll have a sequence number
    # include that sequence number to index directly into that content
    @ref = @seq ? "#{@name}:#{@seq.to_s}" : @name

    #TODO: this should be in options
    # extract transition from classes, or default to 'none'
    @classes.delete_if { |x| x =~ /^transition=(.+)/ && @transition = $1 }
  end

  # This method will extract a section title from subsection slides and then
  # return it to the `section` handler so that it can be carried forward to
  # subsequent slides, until a new section title is discovered.
  #
  # Source:
  #  https://github.com/puppetlabs/showoff/blob/3f43754c84f97be4284bb34f9bc7c42175d45226/lib/showoff.rb#L499-L508
  def updateSectionTitle(section_title)
    if @classes.include? 'subsection'
      matches = @markdown.match(/#+ *(.*?)#*$/)
      @section_title = matches[1] || @section
    else
      @section_title = section_title
    end
    @section_title
  end

  # this is a terrible implementation!
#   def name
#     @markdown.split("\n").find {|line| line.match(/^#/) }
#   end

end
