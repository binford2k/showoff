# Creating a strings file for a new translation

Thanks for helping translate. It's a big job. Your part should be fairly
simple though. All you'll need to do is generate a new strings file, or
update an existing one.

## Generating a new strings file

1. Copy `en.yml` to a new file in the `locales` directory named after the language.
    * Use the two-letter [ISO_639-1](https://en.wikipedia.org/wiki/ISO_639-1) code.
    * The extension *must be* `.yml`; for example `de.yml`.
1. Change the toplevel key from `:en` to the language code as a symbol.
    * For example, `:de` or `:es`.
1. Translate each value without changing the file structure.
    * Quotes around the string are not necessary unless it contains a special character, such as `:`
1. Submit a PR with your new language!

## Using the GitHub web UI

It might be easiest to just do this in the GitHub UI if you don't already have
your own fork & clone of the project.

Copying a file isn't very straightforward in the web UI. Instead, you'll need to
copy the file contents to your clipboard, then create a new file and paste it back
in. Nevertheless, once the file's created, it's quite easy to update this way.
