$:.unshift File.expand_path("../lib", __FILE__)
require 'showoff/version'
require 'date'

Gem::Specification.new do |s|
  s.name              = "showoff"
  s.version           = SHOWOFF_VERSION
  s.date              = Date.today.to_s
  s.summary           = "The best damn presentation software a developer could ever love."
  s.homepage          = "http://github.com/schacon/showoff"
  s.email             = "schacon@gmail.com"
  s.authors           = ["Scott Chacon"]
  s.has_rdoc          = false
  s.require_path      = "lib"
  s.executables       = %w( showoff )
  s.files             = %w( README.rdoc Rakefile LICENSE )
  s.files            += Dir.glob("lib/**/*")
  s.files            += Dir.glob("bin/**/*")
  s.files            += Dir.glob("views/**/*")
  s.files            += Dir.glob("public/**/*")
  s.add_dependency      "sinatra", "~> 1.3"
  s.add_dependency      "json"
  s.add_dependency      "gli",">= 1.3.2"
  s.add_dependency      "parslet"
  s.add_dependency      "htmlentities"
  s.add_dependency      "redcarpet"
  s.add_dependency      "nokogiri"
  s.add_dependency      "sinatra-websocket"
  # workaround a bad dependency in sinatra-websocket
  s.add_dependency      "thin", "~> 1.3"

  s.add_development_dependency "mg"
  s.description       = <<-desc
  ShowOff is a Sinatra web app that reads simple configuration files for a
  presentation.  It is sort of like a Keynote web app engine.  I am using it
  to do all my talks in 2010, because I have a deep hatred in my heart for
  Keynote and yet it is by far the best in the field.

  The idea is that you setup your slide files in section subdirectories and
  then startup the showoff server in that directory.  It will read in your
  showoff.json file for which sections go in which order and then will give
  you a URL to present from.
  desc

  s.post_install_message = <<-desc

  ************************************************************************
  ShowOff can optionally use the RMagick gem for automatic image resizing
  functionality. If RMagick is available, images included in your presentation
  will be resized down to meet size constraints of your presentation, if required.

  Showoff can optionally use the PDFKit gem to autogenerate PDF files on demand.
  Viewers can access the /pdf endpoint to download a generated PDF file. This
  functionality is likely to be deprecated, since it is simpler and easier to
  just print the /print endpoint directly from your browser.
  ************************************************************************

  desc
end
