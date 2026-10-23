#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "apply-templates.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#

FROM debian:trixie-slim

# ensure local python is preferred over distribution python
ENV PATH /usr/local/bin:$PATH

# cannot remove LANG even though https://bugs.python.org/issue19846 is fixed
# - embedded interpreters (uWSGI, mod_wsgi, etc) skip locale coercion and UTF-8 mode before Python 3.15, so they fall back to ASCII
# - musl (alpine) never gets LC_CTYPE set, so anything that reads locale environment variables (babel) finds none
# last attempted removal of LANG broke many users:
# https://github.com/docker-library/python/pull/570
# embedded interpreter reproducer (fails with UnicodeEncodeError without LANG on 3.14 and earlier, needs a non-slim Debian variant for gcc):
# docker run --rm --env LANG= python:3.11 sh -c 'printf "#include <Python.h>\nint main(){Py_Initialize();PyRun_SimpleString(\"print(chr(252),flush=True)\");}" | gcc -x c - $(python3-config --embed --cflags --ldflags) && ./a.out'
ENV LANG C.UTF-8

# runtime dependencies
RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		ca-certificates \
		netbase \
		tzdata \
	; \
	apt-get dist-clean

ENV GPG_KEY A035C8C19219BA821ECEA86B64E628F8D684696D
ENV PYTHON_VERSION 3.11.17
ENV PYTHON_SHA256 bfb74ad39efae27cda510f134ab408e00f9992c56851cfc0b1cdb5646da11599

RUN set -eux; \
	\
	savedAptMark="$(apt-mark showmanual)"; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		dpkg-dev \
		g++ \
		gcc \
		gnupg \
		libbluetooth-dev \
		libbz2-dev \
		libc6-dev \
		libdb-dev \
		libffi-dev \
		libgdbm-dev \
		liblzma-dev \
		libncursesw5-dev \
		libreadline-dev \
		libsqlite3-dev \
		libssl-dev \
		make \
		patch \
		tk-dev \
		uuid-dev \
		wget \
		xz-utils \
		zlib1g-dev \
	; \
	\
	wget -O python.tar.xz "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz"; \
	echo "$PYTHON_SHA256 *python.tar.xz" | sha256sum -c -; \
	wget -O python.tar.xz.asc "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz.asc"; \
	GNUPGHOME="$(mktemp -d)"; export GNUPGHOME; \
	gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys "$GPG_KEY"; \
	gpg --batch --verify python.tar.xz.asc python.tar.xz; \
	gpgconf --kill all; \
	rm -rf "$GNUPGHOME" python.tar.xz.asc; \
	mkdir -p /usr/src/python; \
	tar --extract --directory /usr/src/python --strip-components=1 --file python.tar.xz; \
	rm python.tar.xz; \
	\
	cd /usr/src/python; \
	gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"; \
	./configure \
		--build="$gnuArch" \
		--enable-loadable-sqlite-extensions \
		--enable-optimizations \
		--enable-option-checking=fatal \
		--enable-shared \
		$(test "${gnuArch%%-*}" != 'riscv64' && echo '--with-lto') \
		--with-ensurepip \
	; \
	nproc="$(nproc)"; \
	EXTRA_CFLAGS="$(dpkg-buildflags --get CFLAGS)"; \
	LDFLAGS="$(dpkg-buildflags --get LDFLAGS)"; \
	LDFLAGS="${LDFLAGS:-} -Wl,--strip-all"; \
	make -j "$nproc" \
		"EXTRA_CFLAGS=${EXTRA_CFLAGS:-}" \
		"LDFLAGS=${LDFLAGS:-}" \
	; \
# https://github.com/docker-library/python/issues/784
# prevent accidental usage of a system installed libpython of the same version
	rm python; \
	make -j "$nproc" \
		"EXTRA_CFLAGS=${EXTRA_CFLAGS:-}" \
		"LDFLAGS=${LDFLAGS:-} -Wl,-rpath='\$\$ORIGIN/../lib'" \
		python \
	; \
	make install; \
	\
# https://github.com/docker-library/python/issues/1142
# pip's vendored "certifi" bundle trusts a compromised CA, and upstream is not updating the pip bundled with this version, so patch pip (and the "ensurepip" wheel, for new venvs) to use the system CA bundle instead (like Debian does)
	wget -O pip.patch 'https://salsa.debian.org/python-team/packages/python-pip/-/raw/6f4f079131dcc2902600cee89aa54ef099d32345/debian/patches/certifi-debian-ca-certificates.patch'; \
	echo 'ddb4b85f9468bd9778afed0abd91a7b9af4ec6028c5efbcc236a9f6711cbaa40 *pip.patch' | sha256sum --strict --check -; \
	pipWhl="$(echo /usr/local/lib/python3.11/ensurepip/_bundled/pip-*.whl)"; \
	[ -s "$pipWhl" ]; \
	pipDir="$(mktemp -d)"; \
	python3 -m zipfile --extract "$pipWhl" "$pipDir"; \
	patch --directory "$pipDir" --strip 2 --input "$PWD/pip.patch"; \
	python3 -c 'import shutil, sys; shutil.make_archive(*sys.argv[1:])' "$PWD/pip-patched" zip "$pipDir"; \
	mv -v pip-patched.zip "$pipWhl"; \
	rm -rf "$pipDir"; \
	patch --directory /usr/local/lib/python3.11/site-packages --strip 2 --input "$PWD/pip.patch"; \
	for pipPath in "$pipWhl" /usr/local/lib/python3.11/site-packages; do \
		python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); from pip._vendor import certifi; assert certifi.where() == "/etc/ssl/certs/ca-certificates.crt"' "$pipPath"; \
	done; \
	\
	cd /; \
	rm -rf /usr/src/python; \
	\
	find /usr/local -depth \
		\( \
			\( -type d -a \( -name test -o -name tests -o -name idle_test \) \) \
			-o \( -type f -a \( -name '*.pyc' -o -name '*.pyo' -o -name 'libpython*.a' \) \) \
		\) -exec rm -rf '{}' + \
	; \
	\
	ldconfig; \
	\
	apt-mark auto '.*' > /dev/null; \
	apt-mark manual $savedAptMark; \
	find /usr/local -type f -executable -not \( -name '*tkinter*' \) -exec ldd '{}' ';' \
		| awk '/=>/ { so = $(NF-1); if (index(so, "/usr/local/") == 1) { next }; gsub("^/(usr/)?", "", so); printf "*%s\n", so }' \
		| sort -u \
		| xargs -rt dpkg-query --search \
# https://manpages.debian.org/bookworm/dpkg/dpkg-query.1.en.html#S (we ignore diversions and it'll be really unusual for more than one package to provide any given .so file)
		| awk 'sub(":$", "", $1) { print $1 }' \
		| sort -u \
		| xargs -r apt-mark manual \
	; \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	apt-get dist-clean; \
	\
	export PYTHONDONTWRITEBYTECODE=1; \
	python3 --version; \
	\
	pip3 install \
		--disable-pip-version-check \
		--no-cache-dir \
		--no-compile \
		'setuptools==79.0.1' \
		'wheel==0.46.3' \
	; \
	pip3 --version

# make some useful symlinks that are expected to exist ("/usr/local/bin/python" and friends)
RUN set -eux; \
	for src in idle3 pip3 pydoc3 python3 python3-config; do \
		dst="$(echo "$src" | tr -d 3)"; \
		[ -s "/usr/local/bin/$src" ]; \
		[ ! -e "/usr/local/bin/$dst" ]; \
		ln -svT "$src" "/usr/local/bin/$dst"; \
	done

CMD ["python3"]
