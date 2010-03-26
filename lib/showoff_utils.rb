class ShowOffUtils

  def self.create(dirname,create_samples)
    Dir.mkdir(dirname) if !File.exists?(dirname)
    Dir.chdir(dirname) do
      if create_samples
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
      end

      # create showoff.json
      File.open('showoff.json', 'w+') do |f|
        f.puts '[ {"section":"one"} ]'
      end

      if create_samples
        puts "done. run 'showoff serve' in #{dirname}/ dir to see slideshow"
      else
        puts "done. add slides, modify showoff.json and then run 'showoff serve' in #{dirname}/ dir to see slideshow"
      end
    end
  end

  def self.heroku(name)
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

    puts "herokuized. run something like this to launch your heroku presentation:

      heroku create #{name}
      git add .gems config.ru
      git commit -m 'herokuized'
      git push heroku master
    "
  end
end
