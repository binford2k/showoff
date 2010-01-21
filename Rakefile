begin
  require 'mg'
rescue LoadError
  abort "Please `gem install mg`"
end

class MG
  # Monkey patch until http://github.com/defunkt/mg/commit/no_safe_level
  # is merged and released upstream.
  def spec
    @spec ||= eval(File.read(gemspec))
  end
end

MG.new("showoff.gemspec")
