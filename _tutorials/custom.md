---
layout: default
title: Styles & Scripts
headline: Embedding custom stylesheets and scripts
---

## {{ page.headline }}

Customize the look of your presentation by dropping a CSS stylesheet in the root
of your presentation, next to the `showoff.json` file. Each file with an extension
of `*.css` will automatically be included in the presentation.

The same goes for Javascript files with a file extension of `*.js`. It's possible
to build fairly complex demonstrations into your slides. For example, one Puppet
training course includes a [full Hiera simulation](http://puppetlabs.github.io/hierademo)
on a slide.

In this file listing, we've got a stylesheet customizing a few elements, and we've also
added a highlighting style with a Javascript file.

    $ tree
    .
    ├── Bootstrapping
    │   ├── Section.md
    │   ├── bootstrapping.md
    │   ├── ssl_website.md
    │   ├── start_somewhere.md
    │   └── summary.md
    [...]
    ├── highlight.puppet_output.js
    ├── showoff.json
    └── styles.css

See the Users Manual for more information on the CSS selectors and Javascript triggers
available for use.

* [Custom Javascript](../documentation/AUTHORING_rdoc.html#label-Custom+JavaScript)
* [Custom Stylesheets](../documentation/AUTHORING_rdoc.html#label-Custom+Stylesheets)
