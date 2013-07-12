# $Id: Makefile.am,v 1.12.2.2 2011/06/20 03:43:39 ak Exp $
# Copyright (C) 2013 azumakuniyuki
SYSTEMNAME = Haineko
SYSVERSION = 0.0.1
SUBDIRS = etc lib script

.PHONY: clean
all-am: Makefile
install-am: subdirectories install-depend message

clean-am:
	rm -f ./*~ ./*.bak ./*.tmp 
	find . -name '*.rej' -type f -exec rm -f {} \;
	find . -name '*.rej.orig' -type f -exec rm -f {} \;
	rm -fr ./.temp ./.test

distclean-am: clean-am
	rm -fr ./dist

depend:
	test -d ./dist || mkdir -p ./dist
	for M in `$(GREP) '^requires' ./cpanfile | sed -e "s/', '/-/g" -e 's/^requires //g' | tr -d ';'`; do \
		X=`echo $$M | tr '-' ' '`; \
		Y=`echo $$M | cut -d '-' -f1` ;\
		$(PERL) -I./dist/lib/perl5 -I@libdir@/ -I@libdir@/perl5 -M$$X -le '' 2> /dev/null || \
			$(CPANM) -f -L ./dist --installdeps `echo $$Y | cut -d' ' -f1 | tr -d "'"`; \
	done; 

install-depend:
	test -d ./dist/lib/perl5 && cp -Rp ./dist/lib/perl5 @libdir@/ || :
	for B in morbo hypnotoad; do \
		X="./dist/bin/$$B"; \
		test -x $$X && $(INSTALL) -m 0755 $$X @libexecdir@/ || : ;\
	done

test:
	$(PROVE) -I@prefix@/lib/perl5 t/

subdirectories:
	mkdir -pm 0755 @localstatedir@/db
	mkdir -pm 0755 @prefix@/run
	mkdir -pm 0755 @prefix@/log
	mkdir -pm 0755 @prefix@/tmp
	$(CHMOD) g+w  @localstatedir@/db

message:
	@echo "-----------------------------------------------------------------------------"
	@echo " $(SYSTEMNAME) $(SYSVERSION) "
	@echo "-----------------------------------------------------------------------------"
	@echo " Setting up $(SYSTEMNAME)"
	@echo
	@echo "  1. Edit @sysconfdir@/haineko.cf and other routing table files"
	@echo "  2. Start HTTPd"
	@echo "     > export PERL5LIB=@libdir@/perl5"
	@echo "     > morbo --listen 'http://127.0.0.1:2794' -w @libdir@ -w @sysconfdir@ @prefix@/script/haineko"
	@echo "     OR"
	@echo "     > export PERL5LIB=@libdir@/perl5"
	@echo "     > hypnotoad @prefix@/script/haineko"
	@echo "  3. Connect http://127.0.0.1:2794"
	@echo
	@echo "-----------------------------------------------------------------------------"
	@echo " To show this screen, type 'make message' and hit 'Return' key"
	@echo "-----------------------------------------------------------------------------"
	@echo

