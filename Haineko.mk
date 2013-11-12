# $Id: Makefile,v 1.1 2010/02/11 10:49:59 ak Exp $
# Haineko.mk
#  __  __       _         __ _ _      
# |  \/  | __ _| | _____ / _(_) | ___ 
# | |\/| |/ _` | |/ / _ \ |_| | |/ _ \
# | |  | | (_| |   <  __/  _| | |  __/
# |_|  |_|\__,_|_|\_\___|_| |_|_|\___|
# ---------------------------------------------------------------------------
HERE = $(shell `pwd`)
NEKO = 'http://127.0.0.1:2794/submit'
MAKE = /usr/bin/make
PERL = /usr/local/bin/perl
CURL = /usr/bin/curl -X POST
PROVE= /usr/local/bin/prove -Ilib --timer
MINIL= /usr/local/bin/minil
CF = ./etc/haineko.cf-debug
JQ = /usr/local/bin/jq -M .
CP = /bin/cp
RM = /bin/rm -f
MV = /bin/mv
GIT = /usr/bin/git
CTL = ./bin/hainekoctl

.PHONY: clean

start:
	netstat -tan | grep -E '127.0.0.1[.:]2794' || $(CTL) start -d -C $(CF) &
	sleep 1

stop:
	$(CTL) stop

send: start
	$(CURL) -d'@tmp/email.json' $(NEKO) | $(JQ)

test: user-test author-test

user-test:
	$(PROVE) t/

author-test: start
	$(PROVE) xt/

release-test: start
	$(CP) ./README.md /tmp
	$(MAKE) -f Haineko.mk clean
	$(MINIL) test
	$(CP) /tmp/README.md ./
	$(PERL) -i -ple 's|<.+[@]gmail.com>|<perl.org\@azumakuniyuki.org>|' META.json

push:
	for G in pchan github; do \
		$(GIT) push --tags $$G master; \
	done

clean:
	yes | $(MINIL) clean
	$(RM) -r ./build
	for F in authinfo haineko.cf mailertable password recipients relayhosts sendermt; do \
		$(RM) etc/$$F; \
	done

