FILES=		src/Client.php \
		src/Config.php \
		src/Error/RemoteError.php \
		src/Remote/Fallback.php \
		src/Remote.php \
		src/Whitelist/WhitelistInterface.php \
		src/Whitelist/Privsepd.php \
		src/Privsepd.php \
		privsepd.php

STUBINDEX=	privsepd.php
PREFIX= 	/usr/local
MANDIR?= 	${DESTDIR}${PREFIX}/man
MAN3DIR?= 	${MANDIR}/man3
MAN5DIR?= 	${MANDIR}/man5
MAN8DIR?= 	${MANDIR}/man8
INSTALL?=	/usr/bin/env install
INSTALL_BIN=	${INSTALL} -m 0755
INSTALL_MAN=	${INSTALL} -m 0644
PHP?=		"/usr/bin/env php"

TEST_TARGETS=	01_environment.sh \
		02_attributes.sh \
		03_method.sh \
		04_return.sh \
		05_arguments.sh \
		06_callbacks.sh \
		07_clone.sh \
		08_invoke.sh \
		09_throw.sh \
		10_multi.sh \
		11_destruct.sh \
		12_timeout.sh

all: privsepd.phar

privsepdStubFile.php:
	php -r "echo Phar::createDefaultStub('${STUBINDEX}');" > privsepdStubFile.php

privsepd.phar: privsepdStubFile.php ${FILES}
	phar pack -f privsepd.phar -b '#!'${PHP} -s privsepdStubFile.php ${FILES}

install: all
	mkdir -p ${MAN8DIR}
	mkdir -p ${MAN5DIR}
	mkdir -p ${MAN3DIR}
	mkdir -p ${DESTDIR}${PREFIX}/sbin
	${INSTALL_BIN} privsepd.phar ${DESTDIR}${PREFIX}/sbin/privsepd
	${INSTALL_MAN} man/privsepd.8 ${MAN8DIR}/privsepd.8
	${INSTALL_MAN} man/privsepd.conf.5 ${MAN5DIR}/privsepd.conf.5
	${INSTALL_MAN} man/remote.3php ${MAN3DIR}/remote.3php

uninstall:
	rm -f ${DESTDIR}${PREFIX}/sbin/privsepd
	rm -f ${MAN8DIR}/privsepd.8
	rm -f ${MAN5DIR}/privsepd.conf.5
	rm -f ${MAN3DIR}/remote.3php

test:
	@echo Running regressing tests
	cd regress; for test_target in ${TEST_TARGETS}; do \
		echo "Running test script $$test_target"; /bin/sh $$test_target; \
	done
	@echo Regressing tests successful

clean:
	rm -f ./privsepd.phar
	rm -f privsepdStubFile.php

.PHONY: install uninstall test clean
