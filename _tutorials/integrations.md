---
layout: default
title: Integrations
headline: Web service integrations
---

## {{ page.headline }}

Showoff has two main methods for integrating with web services. Both are designed
primarily for larger teams working on one or more shared presentations, but there's
nothing saying you can't use them on a team of one!

## Filing issues on slides

If you include an `issues` key in your `showoff.json` file, then the Presentation
view will have a button to *Report Issue With Slide*. When you click the button,
a new window or tab is opened up with the issue title pre-filled with the name
of the slide you're currently viewing.

```json
"issues": "https://github.com/username/presentation/issues/new?title=",
```

This example links into a Github repository where the presentation source is
located, but you can use any issue tracker with a similar URL scheme. If you're
willing to write a little code, you can even get more creative. For example,
Puppet uses the Jira issue tracker, so a small amount of [custom
Javascript](custom.html) rewrites the URL into a popup Jira issue collector.


## Editing slides directly in the repository

If you include an `edit` key in your `showoff.json` file, then Showoff provides
buttons in both the Presenter view and the Audience view for editing the current
slide in a web-based editor. This is designed for group editing sessions.
Simultaneous editing of multiple slide files is easy to do.

```json
"edit": "https://github.com/username/presentation/edit/master/",
```

Showoff must be started with the `--edit` flag.

    $ showoff serve --edit

**Note**: Clicking on the title in the upper left of the Presenter view will
open the editor associated with Markdown files on your local machine, as shown
in the [Quickstart](../quickstart.html)
