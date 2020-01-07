class Showoff
  require 'showoff/config'
  require 'showoff/compiler'
  require 'showoff/presentation'
  require 'showoff/state'
  require 'showoff/locale'

  def self.do_static(args, options)
    puts 'Hello world!'

    Showoff::Locale.setContentLocale(options[:language])
    presentation = Showoff::Presentation.new(options)

    puts presentation.render
    puts '------------------'
    presentation.sections.each do |section|
      puts section.name
      section.slides.each do |slide|
        puts "  - #{slide.name}"
      end
    end
  end

end
