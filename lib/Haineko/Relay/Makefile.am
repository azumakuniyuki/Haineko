# $Id: Makefile.am,v 1.4.2.1 2011/06/20 03:43:40 ak Exp $
# Copyright (C) 2013 azumakuniyuki
distdir = $(BUILDROOT)/dist/lib/Haineko/Relay
instdir = @prefix@/lib/Haineko/Relay
pkgdatadir = @libdir@/Haineko/Relay
pkgdata_DATA = ESMTP.pm SendGrid.pm

.PHONY: clean
all-am: 
	test -d $(distdir) || mkdir -p $(distdir)
	cp -Rp $(pkgdata_DATA) $(distdir)/

install-am: all-am
	test -d $(instdir) || mkdir -p $(instdir)
	test -d $(pkgdatadir) || mkdir -p $(pkgdatadir)
	for P in $(pkgdata_DATA) ; do \
		$(INSTALL) -c -m 0644 $(distdir)/$$P $(pkgdatadir)/ ;\
	done

uninstall-am:
	rm -f $(pkgdatadir)/*.pm

clean-am:
	:

