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

### Serving via SSL

Now that you've password protected your presentation, you've also got the option
of serving it via SSL for greater security. Enable it with:

    "ssl": true,

This will autogenerate a self-signed certificate and enable HTTPS for your
presentation. Note that some browsers will not allow the websocket connection
used to enable *Follow Mode* with a self-signed certificate unless all viewers
permanently accept the certificate.

If you'd rather not use self-signed certificates, you can provide your own with:
    
    "ssl": true,
    "ssl_certificate": "/path/to/some/certificate.pem",
    "ssl_private_key": "/path/to/the/corresponding/private_key.pem",

------------

#### Let's Encrypt CA Certificates

If you are hosting your presentations on a public address that resolves properly,
then you have the option of requesting those certificates from the [Let's Encrypt
CA](https://letsencrypt.org) using something like the following:

    $ certbot certonly --standalone -d preso.example.com

Your certificates will be saved into `/etc/letsencrypt/live/$domain`, so you can
then point your `showoff.json` to those files.

    "ssl": true,
    "ssl_certificate": "/etc/letsencrypt/live/preso.example.com/cert.pem",
    "ssl_private_key": "/etc/letsencrypt/live/preso.example.com/privkey.pem",

See the [Certbot User Guide](https://certbot.eff.org/docs/using.html) for more
information on the tool.
