class Showoff
  require 'showoff/config'
  require 'showoff/compiler'
  require 'showoff/presentation'
  require 'showoff/state'
  require 'showoff/locale'
  require 'showoff/logger'

  GEMROOT = File.expand_path(File.join(File.dirname(__FILE__), '..'))

  def self.do_static(args, options)
    Showoff::State.set(:format, args[0] || 'web')
    Showoff::State.set(:supplemental, args[1]) if args[0] == 'supplemental'

    Showoff::Locale.setContentLocale(options[:language])
    presentation = Showoff::Presentation.new(options)

    makeSnapshot(presentation)

    generatePDF if Showoff::State.get(:format) == 'pdf'

#     puts '------------------'
#     presentation.sections.each do |section|
#       puts section.name
#       section.slides.each do |slide|
#         puts "  - #{slide.name}"
#       end
#     end
  end

  # Generate a static HTML snapshot of the presentation in the `static` directory.
  # Note that the `Showoff::Presentation` determines the format of the generated
  # presentation based on the content requested.
  #
  # @see
  #     https://github.com/puppetlabs/showoff/blob/220d6eef4c5942eda625dd6edc5370c7490eced7/lib/showoff.rb#L1506-L1574
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
        Showoff::Logger.warn "Missing source file: #{path}"
      end
    end
  end

  # Generate a PDF version of the presentation in the current directory. This
  # requires that the HTML snaphot exists, and it will *remove* that snapshot
  # if the PDF generation is successful.
  #
  # @note
  #     wkhtmltopdf is terrible and will often report hard failures even after
  #     successfully building a PDF. Therefore, we check file existence and
  #     display different error messaging.
  # @see
  #     https://github.com/puppetlabs/showoff/blob/220d6eef4c5942eda625dd6edc5370c7490eced7/lib/showoff.rb#L1447-L1471
  def self.generatePDF
    begin
      require 'pdfkit'
      output = Showoff::Config.get('name')+'.pdf'

      kit = PDFKit.new(File.new('static/index.html'), Showoff::Config.get('pdf_options'))
      kit.to_file(output)
      FileUtils.rm_rf('static')

    rescue RuntimeError => e
      if File.exist? output
        Showoff::Logger.warn "Your PDF was generated, but PDFkit reported an error. Inspect the file #{output} for suitability."
        Showoff::Logger.warn "You might try loading `static/index.html` in a web browser and checking the developer console for 404 errors."
      else
        Showoff::Logger.error "Generating your PDF with wkhtmltopdf was not successful."
        Showoff::Logger.error "Try running the following command manually to see what it's failing on."
        Showoff::Logger.error e.message.sub('--quiet', '')
      end
    rescue LoadError
      Showoff::Logger.error 'Generating a PDF version of your presentation requires the `pdfkit` gem.'
    end

  end

end
