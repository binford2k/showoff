#! /bin/sh

TITLE="My Presentation"
FOOTER_LEFT="My Presentation"
FOOTER_RIGHT="©2016 My Name"

rm -rf static
showoff static print
wkhtmltopdf -s Letter --print-media-type --quiet \
    --footer-left "${FOOTER_LEFT}"               \
    --footer-center '[page]'                     \
    --footer-right "${FOOTER_RIGHT}"             \
    --header-center '[section]'                  \
    --title "${TITLE}"                           \
    'static/index.html' presentation.pdf
