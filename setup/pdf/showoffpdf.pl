#!/usr/bin/env perl

=head1 NAME

s5pdf - Convert an S5 presentation to PDF

=head1 SYNOPSIS

s5pdf [OPTION]... URI [FILE]

    -s,        --show           show the presentation
    -c FILE,   --css            css style sheet to apply to presentation
    -v,        --verbose        enable verbose mode
    -w WIDTH,  --width WIDHT    the width of the slides in pixels
    -h HEIGHT, --height HEIGHT  the height of the slides in pixels
    -S,        --no-steps       render only full slides (skip the steps)
    -z LEVEL,  --zoom LEVEL     zoom level (negative values zoom out, positive zoom in)
    -p MS,     --pause MS       number of milliseconds to wait before taking a screenshot
    -h,        --help           print this help message

Simple usage:

    # Presentation with a zoom out of 2 levels (smaller fonts)
    s5pdf --zoom -2 s5-presentation.html

=head1 DESCRIPTION

Convert and s5 presentation into a PDF.

=cut

use strict;
use warnings;

use Data::Dumper;
use Getopt::Long qw(:config auto_help);
use Pod::Usage;
use URI;
use File::Basename qw(fileparse);
use Cwd qw(abs_path);

use Gtk3;
use Glib::Object::Introspection;
use Gtk3::WebKit;
use Cairo::GObject;
use Glib ':constants';


sub main {
    Gtk3::init();

    my $do_steps = 1;
    GetOptions(
        'v|verbose'  => \my $verbose,
        's|show'     => \my $show,
        'c|css=s'      => \my $css,
        'w|width=i'  => \my $width,
        'h|height=i' => \my $height,
        'z|zoom=i'   => \my $zoom,
        'p|pause=i'  => \my $timeout,
        'steps!'     => \$do_steps,
    ) or pod2usage(1);

    my ($uri, $filename) = @ARGV;

    $uri      ||= 'http://localhost:9090/';
    $filename ||= 'showoff.pdf';

    $uri = "file://" . abs_path($uri) if -e $uri;
    $css =~ s/\.css// if $css;

    # The default file name is based on their uri's filename
    $filename ||= sprintf "%s.pdf", fileparse(URI->new($uri)->path, qr/\.[^.]*/) || 's5';

    my $view = Gtk3::WebKit::WebView->new();
    $view->set('zoom-level', 1 + ($zoom/10)) if $zoom;

    # Introduce some JavaScript helper methods. This methods will communicate
    # with the Perl script by writting data to the consolse.
    $view->execute_script(qq{
        function _is_end_of_slides () {
            ret = (slidenum == slideTotal - 1) ? true : false ;
            console.log("showoff-end-of-slides: " + ret);
            return ret;
        }

        function _next_slide () {
            nextStep();
            _is_end_of_slides();
        }
    });


    # Start taking screenshot as soon as the document is loaded. Maybe we want
    # to add an onload callback and to log a message once we're ready. We want
    # to take a screenshot only when the page is done being rendered.
    $view->signal_connect('notify::load-status' => sub {
        return unless $view->get_uri and ($view->get_load_status eq 'finished');

        # We take a screenshot now
        # Sometimes the program dies with:
        #  (<unknown>:19092): Gtk-CRITICAL **: gtk_widget_draw: assertion `!widget->priv->alloc_needed' failed
        # This seem to happend is there's a newtwork error and we can't download
        # external stuff (e.g. facebook iframe). This timeout seems to help a bit.
        Glib::Idle->add(sub {
            $view->execute_script("setCurrentStyle('$css')") if $css;
            $view->execute_script('toggleFooter();');
            $view->execute_script('_is_end_of_slides();');
        });
    });
    $view->load_uri($uri);


    # The JavaScripts communicates with Perl by writting into the console. This
    # is a hack but this is the best way that I could find so far.
    my $surface;
    my $count = 0;
    $view->signal_connect('console-message' => sub {
        my ($widget, $message, $line, $source_id) = @_;
        #print "CONSOLE $message at $line $source_id\n" if $verbose;

        if ($message =~ /^ReferenceError: /) {
            # JavaScript error, we stop the program
            print "$message\n";
            print "End of program caused by a JavaScript error\n";
            Gtk3->main_quit();
        }

        my ($end) = ( $message =~ /^showoff-end-of-slides: (true|false)$/) or return TRUE;

        # See if we need to create a new PDF or a new page
        if ($surface) {
            $surface->show_page();
        }
        else {
            my ($width, $height) = ($view->get_allocated_width, $view->get_allocated_height);
            $surface = Cairo::PdfSurface->create($filename, $width, $height);
        }

        # A new slide has been rendered on screen, we save it to the pdf
        my $grab_pdf = sub  {
            ++$count;
            print "Saving slide $count\n";
            my $cr = Cairo::Context->create($surface);
            $view->draw($cr);

            # Go to the next slide or stop grabbing screenshots
            if ($end eq 'true') {
                # No more slides to grab
                my $s = $count > 1 ? 's' : '';
                print "Presentation $filename has $count slide$s\n";
                Gtk3->main_quit();
            }
            else {
                # Go on with the slide
                $view->execute_script('_next_slide();');
            }
        };

        if ($timeout) {
            Glib::Timeout->add($timeout, $grab_pdf);
        }
        else {
            Glib::Idle->add($grab_pdf);
        }

        return TRUE;
    });

    my $window = $show ? Gtk3::Window->new('toplevel') : Gtk3::OffscreenWindow->new();
    $window->set_default_size($width || 1024, $height || 768);
    $window->add($view);
    $window->show_all();

    Gtk3->main();
    return 0;
}


exit main() unless caller;
