$:.unshift File.expand_path("../lib", __FILE__)
require 'showoff/version'
require 'date'

Gem::Specification.new do |s|
  s.name              = "showoff"
  s.version           = SHOWOFF_VERSION
  s.date              = Date.today.to_s
  s.summary           = "The best damn presentation software a developer could ever love."
  s.homepage          = "https://puppetlabs.github.io/showoff"
  s.license           = 'MIT'
  s.email             = "eduteam@puppet.com"
  s.authors           = ["Scott Chacon","Ben Ford"]
  s.require_path      = "lib"
  s.executables       = %w( showoff )
  s.files             = %w( README.md Rakefile LICENSE )
  s.files            += Dir.glob("lib/**/*")
  s.files            += Dir.glob("bin/**/*")
  s.files            += Dir.glob("views/**/*")
  s.files            += Dir.glob("public/**/*")
  s.files            += Dir.glob("locales/**/*")
  s.add_dependency      "commonmarker",      "~> 0.21"
  s.add_dependency      "fidget",            "~> 0.0"
  s.add_dependency      "gli",               "~> 2.20"
  s.add_dependency      "htmlentities",      "~> 4.3"
  s.add_dependency      "i18n",              "~> 1.8"
  s.add_dependency      "iso-639",           "~> 0.3"
  s.add_dependency      "json",              "~> 2.5"
  s.add_dependency      "nokogiri",          "~> 1.11"
  s.add_dependency      "parslet",           "~> 2.0"
  s.add_dependency      "rack-contrib",      "~> 2.3"
  s.add_dependency      "redcarpet",         "~> 3.5"
  s.add_dependency      "sinatra",           ">= 2.1", "< 5.0"
  s.add_dependency      "sinatra-websocket", "~> 0.3"
  s.add_dependency      "tilt",              "~> 2.0"

  s.add_development_dependency "mg",         "~> 0.0"
  s.description       = <<-desc
  Showoff is a Sinatra web app that reads simple configuration files for a
  presentation.  It is sort of like a Keynote web app engine.  I am using it
  to do all my talks in 2010, because I have a deep hatred in my heart for
  Keynote and yet it is by far the best in the field.

  The idea is that you setup your slide files in section subdirectories and
  then startup the showoff server in that directory.  It will read in your
  showoff.json file for which sections go in which order and then will give
  you a URL to present from.
  desc

end
