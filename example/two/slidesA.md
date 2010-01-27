!SLIDE subsection

# Subsection Slide #

!SLIDE

# Code Slide #

	@@@ ruby
	require 'sinatra/base'

	class MyApp < Sinatra::Base
	  set :sessions, true
	  set :foo, 'bar'

	  get '/' do
	    'Hello world!'
	  end
	end
	

!SLIDE

# Executable JavaScript #

	@@@ javaScript
	result = 3 + 3;
	
!SLIDE

# Executable Ruby #

	@@@ ruby
	x = 2
	3.times { x = x * x }
	x