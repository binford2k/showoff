---
layout: default
title: Validating Code
headline: Validating code blocks on slides
---

## {{ page.headline }}

Showoff makes it easy to localize your content. It can even present multiple
translations simultaneously! You'll need to do all the hard work of translating
your material, of course.

You can try out an example in the *Internationalization* section of this
[demo presentation](https://github.com/binford2k/showoff_demo.git):

    $ docker run -p 9090:9090 binford2k/showoff showoff serve -u https://github.com/binford2k/showoff_demo.git 

## Translating a presentation

First, make a copy of your presentation in the locale directory. Substitute the
country language code in the commands below:

    $ cd my-presentation
    $ mkdir -p locales/es
    $ cp -r !(locales) locales/es/
    $ mkdir -p locales/de
    $ cp -r !(locales) locales/de/
    $ showoff serve

Now translate each copy, via any service or process that works for you. If you're
translating by hand, a reasonable workflow might be to select the language you
want to translate to and then page through the presentation, editing each slide
by clicking its name in the Presenter view. See the [Quickstart](quickstart.html)
for more information.

Now, any time an audience member loads your presentation and you've got a
localized version in the language that user's browser is set to, Showoff will
serve that version. Each viewer will see the language most appropriate to their
settings.

You may have noticed that translating text in copied images is a bit tedious.
Luckily, we've got you covered. Showoff can automatically translate SVG images
for you. Create a `locales/strings.json` file with localized strings for each
language you want to support.

Then save your SVG images with translation tags, like `{{greeting}}`. This will
be replaced with the corresponding string for the current language when the
presentation in loaded.

Examples:

* [`locales/strings.json`](https://github.com/binford2k/showoff_demo/blob/master/locales/strings.json)
* [`translation_demo.svg`](https://github.com/binford2k/showoff_demo/blob/master/_images/translation_demo.svg)

## Documentation

See the [User Manual](/documentation/INTERNATIONALIZATION_rdoc.html)