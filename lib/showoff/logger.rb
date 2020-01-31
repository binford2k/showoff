require 'logger'
class Showoff::Logger
  @@logger = Logger.new(STDERR)
  @@logger.progname = 'Showoff'
  @@logger.formatter = proc { |severity,datetime,progname,msg| "(#{progname}) #{severity}: #{msg}\n" }
  @@logger.level = Showoff::State.get(:verbose) ? Logger::DEBUG : Logger::WARN
  @@logger.level = Logger::WARN

  [:debug, :info, :warn, :error, :fatal].each do |meth|
    define_singleton_method(meth) do |msg|
      @@logger.send(meth, msg)
    end
  end

end
