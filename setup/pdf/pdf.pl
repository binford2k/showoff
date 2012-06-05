#!/usr/bin/env perl

# test script from http://potyl.github.com/Talk-WebKit-Perl/#slide-13

use strict;
use warnings;

use Gtk3 -init;
use Gtk3::WebKit;
use Cairo::GObject;

# Build a WebKit frame
my $view = Gtk3::WebKit::WebView->new();
$view->load_uri('http://www.puppetlabs.com');

# With Gtk3 we can use offscreen rendering!
my $window = Gtk3::OffscreenWindow->new();
$window->add($view);
$window->show_all();

# Save the page as PDF file once loaded
$view->signal_connect('notify::load-status' => sub {

    # Wait for the page to be loaded
    return unless $view->get_uri and $view->get_load_status eq 'finished';

    # Use Cairo to grab a PDF (we can also use SVG, PostScript or PNG)
    my ($width, $height) = ($view->get_allocated_width, $view->get_allocated_height);
    my $surface = Cairo::PdfSurface->create("screenshot.pdf", $width, $height);
    my $cr = Cairo::Context->create($surface);
    $view->draw($cr);

    Gtk3->main_quit();
});

Gtk3->main();
