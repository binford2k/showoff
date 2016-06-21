---
layout: default
title: Supplemental Material
headline: Supplemental Presentation Materials
---

## {{ page.headline }}

Often it's useful to have alternate or supplemental documents to go along with
your presentation. For example, Puppet training courseware includes a lab
exercise manual along with the presentation. These manuals are generated from
the same source material so it's very easy to keep in sync if we decide to
change the ordering or update a lab.

Simply create a slide with markup like the following:

    <!SLIDE supplemental exercises>
    # Lab: This is a lab
    ## Objective: Do something
    [... slide content ...]

Remember that multiple slides can be contained inside a single Markdown file.
When you have slides and supplemental material that are related to one another,
this practice makes it very easy to make relocatable content. The supplemental
slides are styled to work as pages rather than a slide in your presentation.

For example, these three slide definitions reside in a single file:

    <!SLIDE exercises>
    # Lab: This is a lab
    ## Objective: Do something
    
    A quick summary of the lab
    
    
    <!SLIDE supplemental exercises>
    # Lab: This is a lab
    ## Objective: Do something
    
    The full guide for the lab
    
    
    <!SLIDE supplemental solutions>
    # Lab: This is a lab
    ## Objective: Do something
    
    A suggested solution for the lab.


### Accessing the supplemental material

To get to the supplemental material, you can browse to [http://localhost:9090/supplemental/$type-name](http://localhost:9090/supplemental/$type-name).
For example, the material described in the example above would be accessed at
[http://localhost:9090/supplemental/exercises](http://localhost:9090/supplemental/exercises).

Depending on your use case, it might be useful to generate a static HTML copy
using Showoff's command line interface.

    $ showoff static print supplemental exercises

This will generate a static copy of the material in the `static` directory. This
can be opened directly in a browser, or can be turned into a PDF file with a tool
like `wkhtmltopdf` or PrinceXML.


