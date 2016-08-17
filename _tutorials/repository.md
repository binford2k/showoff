---
layout: default
title: Repositories
headline: Serving from a git repository
---

## {{ page.headline }}

If you are lucky enough to be storing your presentations in one or more git
repositories, then you'll be happy to know that Showoff talks git natively.
Simply pass the proper parameters and Showoff will clone and serve your
presentation without any fuss. It knows how to check out branches and will
even pull updates when you reload the content.

    $ showoff serve --git_url git@github.com:binford2k/catalog_security.git --git_branch dev
    
    -------------------------
    
    Your ShowOff presentation is now starting up.
    
    To view it plainly, visit [ http://localhost:9090 ]
    
    To run it from presenter view, go to: [ http://localhost:9090/presenter ]
    
    -------------------------
    
    Cloning into '/var/folders/km/cz24f0_j1bs4sh93q82sftp00000gq/T/d20160817-25603-hzav93'...
    remote: Counting objects: 4178, done.
    remote: Compressing objects: 100% (3630/3630), done.
    remote: Total 4178 (delta 669), reused 2422 (delta 247), pack-reused 0
    Receiving objects: 100% (4178/4178), 72.40 MiB | 3.78 MiB/s, done.
    Resolving deltas: 100% (669/669), done.
    Checking connectivity... done.
    == Sinatra (v1.4.7) has taken the stage on 9090 for development with backup from Thin
    Thin web server (v1.7.0 codename Dunder Mifflin)
    Maximum connections set to 1024
    Listening on 0.0.0.0:9090, CTRL+C to stop
     Open sockets: 1
 
 
Showoff only knows git, but it can clone from any URL that the `git` command-line
tool can use. This means that it doesn't matter whether your presentation is stored
on GitHub, an internal GitLab server, or Atlassian Stash. As long as `git` can talk
to it, Showoff can too.

See the options listed by running `showoff serve --help`. You can pass in the address
of any git server, a branch to check out, and a path within the repository where your
presentation is stored. Note that if your repository requires authentication, you'll
need to set up keys or HTTP auth with the `git` command line tool to avoid password prompts.

### Online Editing

If you configure the `showoff.json` stored in your repository with an `edit` key as
detailed in the [Integrations](integrations.html) section, then you can serve from
a repository and edit directly in the repository using the online editor and never
have to deal with managing a repository clone.

Simply press the `r` key after saving changes in the repository. Showoff will pull
down any new commits and then serve them up in your presentation view.
