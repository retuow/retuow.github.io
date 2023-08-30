#!/bin/bash

cd src
rst2html5 \
    --generator \
    --stylesheet-path=minimal.css,responsive.css,gruvbox.css \
    archsetup.rst \
    ../index.html
