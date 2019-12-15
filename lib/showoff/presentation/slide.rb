require 'erb'

class Showoff::Presentation::Slide
  attr_reader :section, :section_title, :name, :seq, :id, :ref, :background, :transition, :markdown, :classes

  def initialize(options, content, context={})
    @markdown   = content
    @template   = 'default'
    @transition = 'none'
    @classes    = []
    parseOptionString!(options)
    setContext!(context)
  end

  def render
    content = Showoff::Compiler.new(@options).render(@markdown)

    ERB.new(File.read(File.join('views','slide.erb')), nil, '-').result(binding)
  end

  def parseOptionString!(options)
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
        else
          $logger.warning "Unknown slide option: #{key}=#{val}"
        end
      end
    end

    if matches[3]
      @classes = matches[3].split
    end
  end

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

  # this is a terrible implementation!
#   def name
#     @markdown.split("\n").find {|line| line.match(/^#/) }
#   end

end
