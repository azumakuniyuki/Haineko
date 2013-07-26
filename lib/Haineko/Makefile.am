# $Id: Makefile.am,v 1.20.2.1 2011/06/20 03:43:39 ak Exp $
# Copyright (C) 2013 azumakuniyuki
SUBDIRS = Ctrl Relay Milter
distdir = $(BUILDROOT)/dist/lib/Haineko
instdir = @libdir@/Haineko
pkgdatadir = @libdir@/Haineko
pkgdata_DATA = Address.pm Greeting.pm Log.pm RFC5321.pm RFC5322.pm \
		Relay.pm Response.pm Session.pm Milter.pm

.PHONY: clean
all-am:
	test -d $(distdir) || mkdir -p $(distdir)
	cp -Rp $(pkgdata_DATA) $(distdir)/

install-am:
	test -d $(instdir) || mkdir -p $(instdir)
	test -d $(pkgdatadir) || mkdir -p $(pkgdatadir)
	for P in $(pkgdata_DATA) ; do \
		$(INSTALL) -c -m 0644 $(distdir)/$$P $(pkgdatadir)/ ;\
	done

uninstall-am:
	rm -f $(pkgdatadir)/*.pm 2> /dev/null

clean-am:
	:


