---
layout: default
title: Home
weight: 1
---

Showoff is a slideshow presentation tool with a twist. It runs as a web application,
with audience interactivity features. This means that your audience can follow along
in their own browsers, can download supplemental materials, can participate in quizzes
or polls, post questions for the presenter, etc. By default, their slideshows will
synchronize with the presenter, but they can switch to self-navigation mode.

![Presenter view](images/presenter.png)

Showoff allows you to author your presentation slides in Markdown, then organize
them with a `showoff.json` file. This file also contains metadata about
the presentation, such as the title, any password protection, etc.

Then you just run `showoff serve` in the presentation directory and open
a browser window.
