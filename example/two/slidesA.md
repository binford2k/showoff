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

!SLIDE execute

# Executable JavaScript #

	@@@ javascript
	result = 3 + 3;

!SLIDE execute

# Executable Ruby #

	@@@ ruby
	result = [1, 2, 3].map { |n| n*7 }

!SLIDE execute
# Executable Coffeescript #

    @@@coffeescript
    add = (a, b) ->
      "#{a}+#{b} is #{a+b}"

    result = add 2, 3


!SLIDE

# Write your own slides #

## Using [markdown](http://daringfireball.net/projects/markdown/)

    !SLIDE
    
    # Title of the slide #
    
    How easy is this?
