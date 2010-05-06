ShowOff Presentation Software
=============================

ShowOff is a Sinatra web app that reads simple configuration files for a
presentation.  It is sort of like a Keynote web app engine - think S5 +
Slidedown.  I am using it to do all my talks in 2010, because I have a deep
hatred in my heart for Keynote and yet it is by far the best in the field.

The idea is that you setup your markdown slide files in section subdirectories
and then startup the showoff server in that directory.  It will read in your
showoff.json file for which sections go in which order and then will give
you a URL to present from.

It can:

 * show simple text
 * show images
 * show syntax highlighted code
 * bullets with incremental advancing
 * re-enact command line interactions
 * call up a menu of sections/slides at any time to jump around
 * execute javascript or ruby live and display results
 * do simple transitions (instant, fade, slide in)

It might will can:

 * show a timer - elapsed / remaining
 * perform simple animations of images moving between keyframes
 * show syncronized, hidden notes on another browser (like an iphone)
 * show audience questions / comments (twitter or direct)
 * let audience members go back / catch up as you talk
 * let audience members vote on sections (?)
 * broadcast itself on Bonjour
 * let audience members download slides, code samples or other supplementary material

Some of the nice things are that you can easily version control it, you
can easily move sections between presentations, and you can rearrange or
remove sections easily.

Usage
====================

ShowOff is meant to be run in a ShowOff formatted repository - that means that
it has a showoff.json file and a number of sections (subdirectories) with markdown files for the slides you're presenting.

  $ gem install showoff
  $ git clone (showoff-repo)
  $ cd (showoff-repo)
  $ showoff serve

If you run 'showoff' in the ShowOff directory itself, it will show an example
presentation from the 'example' subdirectory, so you can see what it's like.

Alternatively you can generate a static version of your presentation by either

  $ showoff static

Which will generate a static directory with an index.html and all other necessary files.

Or

$ showoff static pdf

Which will generate a file called <name>.pdf where <name> is the name of the subdirectory.


Slide Format
====================

You can break your slides up into sections of however many subdirectories deep
you need.  ShowOff will recursively check all the directories mentioned in
your showoff.json file for any markdown files (.md).  Each markdown file can
have any number of slides in it, seperating each slide with the '!SLIDE'
keyword and optional slide styles.

For example, if you run 'showoff create my_new_pres' it will create a new
starter presentation for you with one .md file at one/slide.md which will have
the following contents:

  !SLIDE

  # My Presentation #

  !SLIDE bullets incremental transition=fade

  # Bullet Points #

  * first point
  * second point
  * third point

That represents two slides, the first contains just a large title, and the
second is faded into view showing the title and three bullets that are then
incrementally shown. In order for ShowOff to see those slides, your 
showoff.json file needs to look something like this:

  [
    {"section":"one"}
  ]

If you have multiple sections in your talk, you can make this json array
include all the sections you want to show in which order you want to show
them.

Some useful styles for each slide are:

* center - centers images on a slide
* full-page - allows an image to take up the whole slide
* bullets - sizes and seperates bullets properly (fits up to 5, generally)
* smbullets - sizes and seperates more bullets (smaller, closer together)
* subsection - creates a different background for titles
* command - monospaces h1 title slides
* commandline - for pasted commandline sections
    (needs leading '$' for commands, then output on subsequent lines)
* code - monospaces everything on the slide
* incremental - can be used with 'bullets' and 'commandline' styles,
    will incrementally update elements on arrow key rather than switch slides
* small - make all slide text 80%
* smaller - make all slide text 70%
* execute - on js highlighted code slides, you can click on the code
    to execute it and display the results on the slide

Check out the example directory included to see examples of most of these.

Transitions can be supplied through the use of transition=tname on the !SLIDE
definition, where tname is one of the following supported transitions:

 * blindX
 * blindY
 * blindZ
 * cover
 * curtainX
 * curtainY
 * fade
 * fadeZoom
 * growX
 * growY
 * none (this is the default)
 * scrollUp
 * scrollDown
 * scrollLeft
 * scrollRight
 * scrollHorz
 * scrollVert
 * shuffle
 * slideX
 * slideY
 * toss
 * turnUp
 * turnDown
 * turnLeft
 * turnRight
 * uncover
 * wipe
 * zoom

The transitions are provided by jQuery Cycle plugin. See
http://www.malsup.com/jquery/cycle/browser.html to view the effects and 
http://www.malsup.com/jquery/cycle/adv2.html for how to add
custom effects.

You can manage the presentation with the following keys:

 * space, cursor right: next slide
 * shift+space, cursor left: previous slide
 * d: debug mode
 * c: table of contents (vi)
 * f: toggle footer
 * z: toggle help

Real World Usage
====================

So far, ShowOff has been used in the following presentations:

* LinuxConf.au 2010 - Wrangling Git - Scott Chacon
  http://github.com/schacon/showoff-wrangling-git

* SF Ruby Meetup - Resque! - Chris Wanstrath
  http://github.com/defunkt/sfruby-meetup-resque

* RORO Sydney Talk, Feb 2010 - Beyond Actions - Dave Bolton
  http://github.com/lightningdb/roro-syd-beyond-actions

* LRUG's February meeting - Showing Off with Ruby - Joel Chippindale
  http://github.com/mocoso/showing-off-with-ruby

* PyCon 2010 - Hg and Git; Can't we all just get along? - Scott Chacon
  http://github.com/schacon/pycon-hg-git

* ScotRUG lightning talks, February 2010 - Bankjob & Associates - Drew Neil
  http://github.com/nelstrom/bankjob_and_associates
  http://bankjob-and-associates.heroku.com/

* PdxJs Tech Talk - Asynchronous Coding For My Tiny Ruby Brain - Rick Olson
  http://github.com/technoweenie/pdxjs-twitter-node

* RORO Perth Talk - Rails 3; A Brief Introduction — Darcy Laycock
  http://github.com/Sutto/roro-perth-rails-3

* PDXRB Tech Talk - Here's Sinatra - Jesse Cooke
  http://github.com/jc00ke/pdxrb_sinatra

* Edinburgh TechMeetup, April 2010 - HTML5 Video - Drew Neil
  http://github.com/nelstrom/html5_video_presentation
  http://html5-video-slides.heroku.com/

* Red Dirt Ruby Conference May 2010 - Plain Old Tokyo Storage - Jeremy Hinegardner
  http://github.com/copiousfreetime/plain-old-tokyo-storage-presentation
  http://plain-old-tokyo-storage.heroku.com/

If you use it for something, please let me know so I can add it.

Future Plans
====================

I really want this to evolve into a dynamic presentation software server,
that gives the audience a lot of interaction into the presentation -
helping them decide dynamically what the content of the presentation is,
ask questions without interupting the presenter, etc.  I want the audience
to be able to download a dynamically generated PDF of either the actual
talk that was given, or all the available slides, plus supplementary
material. And I want the presenter (me) to be able to push each
presentation to Heroku or GitHub pages for archiving super easily.

Why Not S5 or Slidy or Slidedown?
=================================

S5 and Slidy are really cool, and I was going to use them, but mainly I wanted
something more dynamic.  I wanted Slidy + Slidedown, where I could write my
slideshows in a structured format in sections, where the sections could easily
be moved around and between presentations and could be written in Markdown. I
also like the idea of having interactive presentation system and didn't need
half the features of S5/Slidy (style based print view, auto-scaling, themes,
etc).

Requirements
============

* Ruby (duh)
* Sinatra (and thus Rack)
* BlueCloth
* Nokogiri
* json
* Firefox or Chrome to present
