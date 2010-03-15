require 'rubygems'
require 'sinatra/base'
require 'json'
require 'nokogiri'
require 'showoff_utils'
require 'princely'

begin 
  require 'rdiscount'
rescue LoadError
  require 'bluecloth'
  Markdown = BlueCloth
end
require 'pp'

class ShowOff < Sinatra::Application

  set :views, File.dirname(__FILE__) + '/../views'
  set :public, File.dirname(__FILE__) + '/../public'
  set :pres_dir, 'example'

  def initialize(app=nil)
    super(app)
    puts dir = File.expand_path(File.join(File.dirname(__FILE__), '..'))
    if Dir.pwd == dir
      options.pres_dir = dir + '/example'
    else
      options.pres_dir = Dir.pwd
    end
    puts options.pres_dir
  end

  helpers do
    def load_section_files(section)
      section = File.join(options.pres_dir, section)
      files = Dir.glob("#{section}/**/*").sort
      pp files
      files
    end

    def css_files
      Dir.glob("#{options.pres_dir}/*.css").map { |path| File.basename(path) }
    end

    def js_files
      Dir.glob("#{options.pres_dir}/*.js").map { |path| File.basename(path) }
    end

    def process_markdown(name, content)
      slides = content.split(/^!SLIDE/)
      slides.delete('')
      final = ''
      if slides.size > 1
        seq = 1
      end
      slides.each do |slide|
        md = ''
        # extract content classes
        lines = slide.split("\n")
        content_classes = lines.shift.split
        slide = lines.join("\n")
        # add content class too
        content_classes.unshift "content"
        # extract transition, defaulting to none
        transition = 'none'
        content_classes.delete_if { |x| x =~ /^transition=(.+)/ && transition = $1 }
        puts "classes: #{content_classes.inspect}"
        puts "transition: #{transition}"
        # create html
        md += "<div class=\"slide\" data-transition=\"#{transition}\">"
        if seq
          md += "<div class=\"#{content_classes.join(' ')}\" ref=\"#{name}/#{seq.to_s}\">\n"
          seq += 1
        else
          md += "<div class=\"#{content_classes.join(' ')}\" ref=\"#{name}\">\n"
        end
        sl = Markdown.new(slide).to_html 
        sl = update_image_paths(name, sl)
        md += sl
        md += "</div>\n"
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
      
      html.css('pre').each do |pre|
        pre.css('code').each do |code|
          out = code.text
          lines = out.split("\n")
          if lines.first[0, 3] == '@@@'
            lang = lines.shift.gsub('@@@', '').strip
            pre.set_attribute('class', 'sh_' + lang)
            code.content = lines.join("\n")
          end
        end
      end

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
    
    def get_slides_html
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

    def inline_css(csses, pre = nil)
      css_content = '<style type="text/css">'
      csses.each do |css_file|
        if pre
          css_file = File.join(File.dirname(__FILE__), '..', pre, css_file) 
        else
          css_file = File.join(options.pres_dir, css_file) 
        end
        css_content += File.read(css_file)
      end
      css_content += '</style>'
      css_content
    end

    def inline_js(jses, pre = nil)
      js_content = '<script type="text/javascript">'
      jses.each do |js_file|
        if pre
          js_file = File.join(File.dirname(__FILE__), '..', pre, js_file) 
        else
          js_file = File.join(options.pres_dir, js_file) 
        end
        js_content += File.read(js_file)
      end
      js_content += '</script>'
      js_content
    end

  end

  get '/' do
    erb :index
  end

  get %r{(?:image|file)/(.*)} do
    path = params[:captures].first
    full_path = File.join(options.pres_dir, path)
    send_file full_path
  end

  get '/slides' do
    get_slides_html
  end

  get '/onepage' do
    @slides = get_slides_html
    erb :onepage
  end

  get '/pdf' do
    @slides = get_slides_html
    @no_js = true
    html = erb :onepage
    p = Princely.new
    p.pdf_from_string_to_file(html, '/tmp/preso.pdf')
    send_file '/tmp/preso.pdf'
  end

end
