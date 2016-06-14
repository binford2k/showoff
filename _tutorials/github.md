---
layout: default
title: Publish to Github
headline: Publishing your presentation to GitHub
---

## {{ page.headline }}

Now that you've given your presentation, how do you share it with the world?
Showoff has the built in functionality of compiling a static presentation and
turning that into a `gh-pages` branch of your repository.

Just push the branch and you're live at github.io.

    $ showoff github
    Generating static content
    I've updated your 'gh-pages' branch with the static version of your presentation.
    Push it to GitHub to publish it. Probably something like:

      git push origin gh-pages

See a presentation example at http://binford2k.github.io/catalog_security. Note
that the interactivity features have been appropriately disabled.

To get a fully interactive instance, with presenter controls and follow mode, etc.,
you can stand up a Heroku instance. That will be covered in another tutorial.
