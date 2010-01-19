#! /usr/bin/env ruby

# this script will take a directory full of images and make a showoff
# presentation section out of them

# usage: ./import_images.rb preso section_name /path/to/images

require 'fileutils'
require 'pp'

if ARGV.size < 3
  puts 'usage: ./import_images.rb preso section_name /path/to/images'
  exit
end

preso = ARGV[0]
section = ARGV[1]
path = ARGV[2]

# look for showoff file
if File.exists?(preso)
  Dir.chdir(preso) do
    # make the new directory
    Dir.mkdir(section) rescue nil
    Dir.chdir(section) do
      Dir.mkdir('img') rescue nil
      # copy all the images into img dir
      FileUtils.cp_r(path, "img")
      files = Dir.glob("img/**/*")

      # create the slides file
      filen = section.split('/').last
      filenm = "#{filen}.md"
      File.open(filenm, 'w+') do |f|
        files.each do |img|
          if File.file?(img)
            f.puts "!SLIDE center"
            f.puts "![#{img}](#{img})"
            f.puts
          end
        end
      end
      pp files
    end
  end
end