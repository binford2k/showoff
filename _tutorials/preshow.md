---
layout: default
title: Preshow
headline: Sharing preshow images
---

## {{ page.headline }}

While you're waiting for your talk to begin, or during breaks for longer
presentations, you can run an image slideshow with a timer.

Create a `_preshow` directory to your presentation and add any images you'd
like to show. If desired, you can also put a `preshow.json` file in the same
directory with descriptions of the images.

    $ tree
    .
    ├── _preshow
    │   ├── image01.jpg
    │   ├── image02.jpg
    │   ├── image03.jpg
    │   ├── image04.jpg
    │   └── image05.jpg
    [...]
    ├── section_one
    │   ├── 01_introduction.md
    │   └── 02_more_content.md
    └── showoff.json

Press `P`, enter the number of minutes until the presentation begins and enjoy
the slideshow. Press `P` again to cancel the timer and return to the
presentation or just wait until the timer runs out.
