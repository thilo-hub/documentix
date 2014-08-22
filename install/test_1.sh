#!/bin/sh

find install -name '*.pdf' | sudo -u documentix perl index2_pdf.pl

