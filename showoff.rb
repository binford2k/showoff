require 'rubygems'
require 'sinatra'

class ShowOff < Sinatra::Default
  
  get '/' do
    "ShowOff"
  end
  
end

