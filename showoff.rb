require 'rubygems'
require 'sinatra'
require 'json'
require 'makers-mark'
require 'pp'

set :pres_dir, 'preso'

helpers do
  def load_section_files(section)
    section = File.join(options.pres_dir, section)
    Dir.glob("#{section}/**/*")
  end

  def process_markdown(name, content)
    slides = content.split('!SLIDE')
    slides.map! { |s| s.strip }
    slides.delete('')
    md = ''
    if slides.size > 1
      seq = 1
    end
    slides.each do |slide|
      if seq
        md += "<div class=\"slide\" ref=\"#{name}/#{seq.to_s}\">\n"
        seq += 1
      else
        md += "<div class=\"slide\" ref=\"#{name}\">\n"
      end
      md += MakersMark::Generator.new(slide).to_html rescue ''
      md += "</div>\n"
    end
    md
  end

end

get '/' do
  erb :index
end

get '/slides' do
  index = File.join(options.pres_dir, 'showoff.json')
  files = []
  if File.exists?(index)
    order = JSON.parse(File.read(index))
    order = order.map { |s| s['section'] }
    order.each do |section|
      files << load_section_files(section)
    end
    files = files.flatten
    files = files.select { |f| f =~ /.md/ }
    data = ''
    files.each do |f|
      fname = f.gsub(options.pres_dir + '/', '').gsub('.md', '')
      data += process_markdown(fname, File.read(f))
    end
  end
  data
end