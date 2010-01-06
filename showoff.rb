require 'rubygems'
require 'sinatra/base'

class ShowOff < Sinatra::Base

  get '/' do
    "ShowOff" + options.dir
  end
  
end

