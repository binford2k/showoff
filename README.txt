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
 * re-enact command line interactions
 * do simple transitions (instant, fade, slide in)
 * show a timer - elapsed / remaining
 * perform simple animations of images moving between keyframes
 * show syncronized, hidden notes on another browser (like an iphone)
 * show audience questions / comments (twitter or direct)
 * let audience members go back / catch up as you talk
 * let audience members vote on sections (?)

You can also call up a menu of sections/slides at any time to jump around.

Some of the nice things are that you can easily version control it, you 
can easily move sections between presentations, and you can rearrange or 
remove sections easily. 

It will also optionally broadcast itself on Bonjour so people can download 
slides, code samples or other supplementary material.

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
* Makers-Mark
* Pygments 
* Firefox or Chrome to present