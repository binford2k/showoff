ShowOff Presentation Software
=============================

ShowOff is a Sinatra web app that reads simple configuration files for a
presentation.  It is sort of like a Keynote web app engine.  I am using it
to do all my talks in 2010, because I have a deep hatred in my heart for
Keynote and yet it is by far the best in the field.

The idea is that you setup your slide files in section subdirectories and
then startup the showoff server in that directory.  It will read in your
showoff.json file for which sections go in which order and then will give
you a URL to present from.

It can:

 * show simple text
 * show images
 * show syntax highlighted code
 * bullets with incremental advancing
 * re-enact command line interactions
 * call up a menu of sections/slides at any time to jump around

It might will can:

 * do simple transitions (instant, fade, slide in)
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

ShowOff is meant to be run in a ShowOff formatted repository - that means that it has
a showoff.json file and a number of sections (subdirectories) with markdown files for
the slides you're presenting.

  $ gem install showoff
  $ git clone (showoff-repo)
  $ cd (showoff-repo)
  $ showoff

If you run 'showoff' in the ShowOff directory itself, it will show an example presentation
from the 'example' subdirectory, so you can see what it's like.

You can manage the presentation with the following keys:

 * space, cursor right: next slide
 * cursor left: previous slide
 * d: debug mode
 * c: table of contents (vi)
 * f: toggle footer
 * z: toggle help (this)

Real World Usage
====================

So far, ShowOff has been used in the following presentations:

* LinuxConf.au 2010 - Wrangling Git - Scott Chacon
  http://github.com/schacon/showoff-wrangling-git

* SF Ruby Meetup - Resque! - Chris Wanstrath
  http://github.com/defunkt/ruby-meetup-resque

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
* Firefox or Chrome to present
