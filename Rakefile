desc "Process screenshot thumbnails"
task :screenshots do
  require 'RMagick'
  require 'yaml'
  require 'digest/md5'

  metadata = YAML.load_file('_data/screenshots.yml') rescue {}
  Dir.chdir('screenshots') do
    Dir.glob('*').each do |filename|
      next if filename.start_with? 'thumb.'

      metadata[filename] ||= {}
      output = "thumb.#{filename}"
      md5    = Digest::MD5.file(filename).hexdigest

      next if metadata[filename]['md5'] == md5 and File.exist? output

      puts "Generating #{output}"
      %x{convert #{filename} -resize 250x250 #{output}}

#       img = Magick::Image.ping(filename).first
#       thumb = img.resize_to_fill(250, 250)
#       thumb.write "thumb.#{filename}"

      metadata[filename]['md5']   = md5
      metadata[filename]['thumb'] = output
    end
  end
  File.write('_data/screenshots.yml', metadata.to_yaml)
end
