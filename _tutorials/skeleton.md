---
layout: default
title: Outlines
headline: Creating a presentation from an outline
---

## {{ page.headline }}

If your work style involves creating an outline and then fleshing out each
slide, you'll be happy to know that Showoff provides tooling to make that easy.

Let's say you start with this `showoff.json` file:

```json
{
  "name": "Catalog_security",
  "sections": [
    "Overview/title.md",
    "Overview/Table_of_contents.md",
    "Overview/intro.md",
    "Overview/puppet.md",
    "Overview/configuration.md",
    "Overview/root.md",
    "Overview/good_thing.md",

    "Secrets/Section.md",
    "Secrets/wp_profile.md",
    "Secrets/in_catalog_quiz.md",
    "Secrets/artifacts_master.md",
    "Secrets/artifacts_agent.md",
    "Secrets/artifacts_puppetdb.md",
    "Secrets/artifacts_logs.md",
    "Secrets/artifacts_logs2.md",
    "Secrets/summary.md",

    "Bootstrapping/Section.md",
    "Bootstrapping/start_somewhere.md",
    "Bootstrapping/bootstrapping.md",
    "Bootstrapping/ssl_website.md",
    "Bootstrapping/summary.md",

    "Scrubbing/Section.md",
    "Scrubbing/fortress.md",
    "Scrubbing/master.md",
    "Scrubbing/postrun.md",
    "Scrubbing/features.md",
    "Scrubbing/show_diff.md",

    "Node_Encrypt/Section.md",
    "Node_Encrypt/puppetca.md",
    "Node_Encrypt/introduction.md",
    "Node_Encrypt/features.md",
    "Node_Encrypt/encrypted_file.md",
    "Node_Encrypt/file_demo.md",
    "Node_Encrypt/encrypted_exec.md",
    "Node_Encrypt/exec_demo.md",
    "Node_Encrypt/redact.md",
    "Node_Encrypt/redact_function.md",
    "Node_Encrypt/redact_demo.md",
    "Node_Encrypt/limitations.md",
    "Node_Encrypt/certificates.md",

    "Hiera_eYaml/Section.md",
    "Hiera_eYaml/on_disk.md",
    "Hiera_eYaml/introduction.md",
    "Hiera_eYaml/configuration.md",
    "Hiera_eYaml/using.md",
    "Hiera_eYaml/extending.md",
    "Hiera_eYaml/common_failures.md",

    "Conclusion/Section.md",
    "Conclusion/summary.md",
    "Conclusion/next_steps.md",
    "Conclusion/end.md"
  ]
}
```

In the the root of your presentation directory, simply run `showoff skeleton`:

    $ showoff skeleton
    Creating: Overview/title.md
    Creating: Overview/Table_of_contents.md
    Creating: Overview/intro.md
    Creating: Overview/puppet.md
    Creating: Overview/configuration.md
    Creating: Overview/root.md
    Creating: Overview/good_thing.md
    Creating: Secrets/Section.md
    Creating: Secrets/wp_profile.md
    Creating: Secrets/in_catalog_quiz.md
    Creating: Secrets/artifacts_master.md
    Creating: Secrets/artifacts_agent.md
    Creating: Secrets/artifacts_puppetdb.md
    Creating: Secrets/artifacts_logs.md
    Creating: Secrets/artifacts_logs2.md
    Creating: Secrets/summary.md
    Creating: Bootstrapping/Section.md
    Creating: Bootstrapping/start_somewhere.md
    Creating: Bootstrapping/bootstrapping.md
    Creating: Bootstrapping/ssl_website.md
    Creating: Bootstrapping/summary.md
    Creating: Scrubbing/Section.md
    Creating: Scrubbing/fortress.md
    Creating: Scrubbing/master.md
    Creating: Scrubbing/postrun.md
    Creating: Scrubbing/features.md
    Creating: Scrubbing/show_diff.md
    Creating: Node_Encrypt/Section.md
    Creating: Node_Encrypt/puppetca.md
    Creating: Node_Encrypt/introduction.md
    Creating: Node_Encrypt/features.md
    Creating: Node_Encrypt/encrypted_file.md
    Creating: Node_Encrypt/file_demo.md
    Creating: Node_Encrypt/encrypted_exec.md
    Creating: Node_Encrypt/exec_demo.md
    Creating: Node_Encrypt/redact.md
    Creating: Node_Encrypt/redact_function.md
    Creating: Node_Encrypt/redact_demo.md
    Creating: Node_Encrypt/limitations.md
    Creating: Node_Encrypt/certificates.md
    Creating: Hiera_eYaml/Section.md
    Creating: Hiera_eYaml/on_disk.md
    Creating: Hiera_eYaml/introduction.md
    Creating: Hiera_eYaml/configuration.md
    Creating: Hiera_eYaml/using.md
    Creating: Hiera_eYaml/extending.md
    Creating: Hiera_eYaml/common_failures.md
    Creating: Conclusion/Section.md
    Creating: Conclusion/summary.md
    Creating: Conclusion/next_steps.md
    Creating: Conclusion/end.md
    done. run 'showoff serve' to see your slideshow

Run Showoff and open the Presenter window. You'll see a not-very-interesting
presentation fill the screen. Now it's your job to fill it. Flip through the
slides, and when you see one you want to edit, simply click its name in the
upper left of the window.

Showoff will open it in whatever editor you have registered to open Markdown
files, making quick work of fleshing out your outline.

You'll notice that you don't get any of your new content when you hit the
browser refresh button. Showoff compiles the presentation on first load. Press
the `r` key to rebuild the presentation and see the content you're working on.

