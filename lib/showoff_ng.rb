class Showoff
  require 'showoff/config'
  require 'showoff/compiler'
  require 'showoff/presentation'
  require 'showoff/state'
  require 'showoff/locale'

  GEMROOT = File.expand_path(File.join(File.dirname(__FILE__), '..'))

  def self.do_static(args, options)
    Showoff::State.set(:format, args[0] || 'web')
    Showoff::State.set(:supplemental, args[1]) if args[0] == 'supplemental'

    Showoff::Locale.setContentLocale(options[:language])
    presentation = Showoff::Presentation.new(options)

    makeSnapshot(presentation)

#     puts '------------------'
#     presentation.sections.each do |section|
#       puts section.name
#       section.slides.each do |slide|
#         puts "  - #{slide.name}"
#       end
#     end
  end

  def self.makeSnapshot(presentation)
    FileUtils.mkdir_p 'static'
    File.write(File.join('static', 'index.html'), presentation.static)

    ['js', 'css'].each { |dir|
      src  = File.join(GEMROOT, 'public', dir)
      dest = File.join('static', dir)

      FileUtils.copy_entry(src, dest, false, false, true)
    }

    # now copy all the files we care about
    presentation.assets.each do |path|
      src  = File.join(Showoff::Config.root, path)
      dest = File.join('static', path)

      FileUtils.mkdir_p(File.dirname(dest))
      begin
        FileUtils.copy(src, dest)
      rescue Errno::ENOENT => e
        puts "Missing source file: #{path}"
      end
    end

  end

end
