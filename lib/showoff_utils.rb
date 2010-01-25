class ShowOffUtils

  def self.create
    dirname = ARGV[1]
    return help('create') if !dirname
    Dir.mkdir(dirname) if !File.exists?(dirname)
    Dir.chdir(dirname) do
      # create section
      Dir.mkdir('one')

      # create markdown file
      File.open('one/slide.md', 'w+') do |f|
        f.puts "!SLIDE"
        f.puts "# My Presentation #"
        f.puts
        f.puts "!SLIDE bullets incremental"
        f.puts "# Bullet Points #"
        f.puts
        f.puts "* first point"
        f.puts "* second point"
        f.puts "* third point"
      end

      # create showoff.json
      File.open('showoff.json', 'w+') do |f|
        f.puts '[ {"section":"one"} ]'
      end

      # print help
      puts "done. run 'showoff serve' in #{dirname}/ dir to see slideshow"""
    end
  end

  def self.heroku
    name = ARGV[1]
    return help('heroku') if !name
    if !File.exists?('showoff.json')
      puts "fail. not a showoff directory"
      return false
    end
    # create .gems file
    File.open('.gems', 'w+') do |f|
      f.puts "bluecloth"
      f.puts "nokogiri"
      f.puts "showoff"
    end if !File.exists?('.gems')

    # create config.ru file
    File.open('config.ru', 'w+') do |f|
      f.puts 'require "showoff"'
      f.puts 'run ShowOff.new'
    end if !File.exists?('config.ru')

    `heroku create #{name}`

    puts "herokuized. run something like this to launch your heroku presentation:

      $ git add .gems config.ru
      $ git commit -m 'herokuized'
      $ git push heroku master
    "
  end

  def self.help(verb = nil)
    verb = ARGV[1] if !verb
    case verb
    when 'heroku'
      puts <<-HELP
usage: showoff heroku (heroku-name)

creates the .gems file and config.ru file needed to push a showoff pres to
heroku.  it will then run 'heroku create' for you to register the new project
on heroku and add the remote for you.  then all you need to do is commit the
new created files and run 'git push heroku' to deploy.

HELP
    when 'create'
      puts <<-HELP
usage: showoff create (directory)

this command helps start a new showoff presentation by setting up the
proper directory structure for you.  it takes the directory name you would
like showoff to create for you.

HELP
    else
      puts <<-HELP
usage: showoff (command)

commands:
  serve   serves a showoff presentation from the current directory
  create  generates a new showoff presentation layout
  heroku  sets up your showoff presentation to push to heroku
HELP
    end
  end

end