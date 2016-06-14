---
layout: default
title: Password protection
headline: Password protecting a presentation
---

## {{ page.headline }}

Showoff has two methods of password protection. Pages that are `protected` require
a username and password to acces. This is typically used to prevent others from
controlling your presentation. Pages that are `locked`, however, only require
a viewing key.

You define the pages you want to protect with arrays in your `showoff.json` file.
This configuration would require the viewing key of *foobar* to load and print
the print-friendly version.

    "locked": ["print"],
    "key": "foobar",

You can mix and match exactly which functionality is available to your audience. For
example, if you want to restrict access to the presenter, but allow anyone with
the viewing key to use the print endpoint to generate a PDF file:

    "protected": ["presenter"],
    "locked": ["slides", "print"],

    "key": "foobar",
    "user": "superman",
    "password": "kryptonite",
