# mw-dumptests-docker
Integration tests for MediaWiki xml/sql dumps via docker (eventually).

I do a bunch of end to end testing of the xml/sql dumps against a local
installation of MediaWiki on my laptop. That doesn't help anyone else
who needs to run these tests.

Eventually this repo will be populated with bash scripts that run the
tests and compare the outputs; with Docker files that create a mariadba
image pre-populated with the appropriate tables, and an image with the
xml/sql dumps repo checked out, these bash scripts and supporting config
files and other settings copied in and ready to use.

Eventually.
