#!/bin/sh

xvfb-run --server-args="-screen 0 1200x1024x24" perl pdf.pl
