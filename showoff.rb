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

  def process_markdown(content)
    slides = content.split('!SLIDE')
    slides.map! { |s| s.strip }
    slides.delete('')
    md = ''
    slides.each do |slide|
      md += "<div class=\"slide\">\n"
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
      data += process_markdown(File.read(f))
    end
  end
  data
end