---
layout: default
title: Presentation File
headline: Writing your `showoff.json` presentation file
---

## {{ page.headline }}

A Showoff presentation is defined by the contents of the `showoff.json` file in
the root of the presentation directory. It contains configuration keys that
define metadata about the presentation and describes the slides themselves.

There are a handful of ways to use this file. The simplest is to not use it at
all. Showoff will happily run without a `showoff.json` file by simply assuming
that you intend to use all the Markdown files in the current directory as
slides.  The slides will be displayed in [shell globbing](http://www.tldp.org/LDP/abs/html/globbingref.html)
order, which is more or less alphabetic.

The next way you can use this file is by listing *sections* as directories.
Markdown files in each directory will be displayed in shell globbing order and
the sections will be displayed in the order you define them.

Sections are listed as an array of hashes. A simple example would look like:

```json
{
  "name": "My Presentation",
  "description": "Example Presentation",
  "sections": [
    { "section": "introduction" },
    { "section": "problem"      },
    { "section": "solution"     },
    { "section": "conclusion"   }
  ]
}
```

Finally, if you'd like full control over the order each slide is displayed in,
you can list each Markdown file in the `showoff.json`. If the file paths include
directories, then they'll be split into sections.

For example, this `showoff.json` defines three sections and five slides, all in
the order they're listed in the file.

```json
{
  "name": "My Presentation",
  "description": "Example Presentation",
  "sections": [
    "Intro/intro.md",
    "Intro/summary.md",
    "Content/first.md",
    "Content/second.md",
    "Conclusion/overview.md",
  ]
}
```

There are many more configuration options you can include, from defining passwork
protection, to choosing a syntax highlighting theme, to even choosing and configuring
a Markdown rendering engine. More information is available in the
[User Manual](../documentation/PRESENTATION_rdoc.html)
