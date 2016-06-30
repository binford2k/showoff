---
layout: default
title: Validating Code
headline: Validating code blocks on slides
---

## {{ page.headline }}

Showoff can validate the consistency of a presentation for you. It will make sure
that all files you've listed in your `showoff.json` exist and that all code blocks
contain valid code. If individual files aren't listed, or no `showoff.json` file
exists, then Showoff will iterate files using shell globbing patterns.

    $ showoff validate
    ..................................F...........F......
    Found 2 errors.
     * Invalid puppet code on Node_Encrypt/encrypted_exec.md [1]
     * Invalid shell code on Hiera_eYaml/using.md [5]

Showoff has built-in validators for many languages, including Perl, Puppet,
Python, Ruby, and Shell. For example, it will validate Ruby code with `ruby -c`,
and validate Puppet code with `puppet parser validate`. It's also quite easy to
add your own validation commands.

A validator is just a command that accepts a file path containing code. For
example, you would use `ruby -c $filename` to validate Ruby code in the file
`$filename`.  Configuring custom validators is done in your `showoff.json`:

``` json
"validators": {
    "clojure": "java -jar clojure-syntax-check.jar",
    "java": "javac"
},
```

If you have a validation command that doesn't fit that pattern, you can wrap it
in a shell script.  For example, there doesn't exist a tool to directly validate
a Ruby ERB template, but something like `erb -P -x -T '-' example.erb | ruby -c`
will do the job. Because the filename is in the middle of that command pipeline,
we cannot use it as a Showoff validator directly. Instead, we can wrap it in a
shell script like so:

``` shell
#! /bin/sh
erb -P -x -T '-' $1 | ruby -c
```

And then tell Showoff about it:

``` json
"validators": {
    "erb": "/usr/local/bin/erb_validator"
},
```
