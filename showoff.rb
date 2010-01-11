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
    slides.delete('')
    final = ''
    if slides.size > 1
      seq = 1
    end
    slides.each do |slide|
      md = ''
      lines = slide.split("\n")
      classes = lines.shift
      slide = lines.join("\n")
      if seq
        md += "<div class=\"slide #{classes}\" ref=\"#{name}/#{seq.to_s}\">\n"
        seq += 1
      else
        md += "<div class=\"slide #{classes}\" ref=\"#{name}\">\n"
      end
      sl = MakersMark::Generator.new(slide).to_html rescue ''
      sl = update_image_paths(name, sl)
      md += sl
      md += "</div>\n"
      final += update_commandline_code(md)
    end
    final
  end

  def update_image_paths(path, slide)
    paths = path.split('/')
    paths.pop
    path = paths.join('/')
    slide.gsub(/img src=\"(.*?)\"/, 'img src="/image/' + path + '/\1"') 
  end
  
  def update_commandline_code(slide)
    html = Nokogiri::XML.parse(slide)
    html.css('.commandline > pre > code').each do |code|
      out = code.text
      lines = out.split(/^\$(.*?)$/)
      lines.delete('')
      code.content = ''
      while(lines.size > 0) do
        command = lines.shift
        result = lines.shift
        c = Nokogiri::XML::Node.new('code', html)
        c.set_attribute('class', 'command')
        c.content = '$' + command
        code << c
        c = Nokogiri::XML::Node.new('code', html)
        c.set_attribute('class', 'result')
        c.content = result
        code << c
      end
    end
    html.root.to_s
  end
end

get '/' do
  erb :index
end

get '/image/*' do
  img_file = params[:splat].join('/')
  img = File.join(options.pres_dir, img_file)
  send_file img
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