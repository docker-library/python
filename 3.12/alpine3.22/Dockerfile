#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "apply-templates.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#

FROM alpine:3.22

# ensure local python is preferred over distribution python
ENV PATH /usr/local/bin:$PATH

# cannot remove LANG even though https://bugs.python.org/issue19846 is fixed
ENV LANG C.UTF-8

# runtime dependencies
RUN set -eux; \
	apk add --no-cache \
		ca-certificates \
		tzdata

ENV GPG_KEY 7169605F62C751356D054A26A821E680E5FA6305
ENV PYTHON_VERSION 3.12.11
ENV PYTHON_SHA256 c30bb24b7f1e9a19b11b55a546434f74e739bb4c271a3e3a80ff4380d49f7adb
ENV SQLITE_VERSION 3.50.2
ENV SQLITE_AUTOCONF_VERSION 3500200

RUN set -eux; \
	apk add --no-cache --virtual .build-deps \
		gnupg \
		tar \
		xz \
		wget \
		\
		bluez-dev \
		bzip2-dev \
		dpkg-dev dpkg \
		findutils \
		gcc \
		gdbm-dev \
		libc-dev \
		libffi-dev \
		libnsl-dev \
		libtirpc-dev \
		linux-headers \
		make \
		ncurses-dev \
		openssl-dev \
		pax-utils \
		readline-dev \
		tcl-dev \
		tk \
		tk-dev \
		util-linux-dev \
		xz-dev \
		zlib-dev \
	; \
	\
	# --- Install SQLite 3.50.2 from source ---
	wget "https://www.sqlite.org/2025/sqlite-autoconf-${SQLITE_AUTOCONF_VERSION}.tar.gz"; \
	tar xzf "sqlite-autoconf-${SQLITE_AUTOCONF_VERSION}.tar.gz"; \
	cd "sqlite-autoconf-${SQLITE_AUTOCONF_VERSION}"; \
	./configure --prefix=/usr/local; \
	make -j"$(nproc)"; \
	make install; \
	cd ..; \
	rm -rf "sqlite-autoconf-${SQLITE_AUTOCONF_VERSION}"*; \
	\
	# --- Install Python ---
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
		--enable-option-checking=fatal \
		--enable-shared \
		$(test "$gnuArch" != 'riscv64-linux-musl' && echo '--with-lto') \
		--with-ensurepip \
	; \
	nproc="$(nproc)"; \
	EXTRA_CFLAGS="-DTHREAD_STACK_SIZE=0x100000"; \
	LDFLAGS="${LDFLAGS:--Wl},--strip-all"; \
	arch="$(apk --print-arch)"; \
	case "$arch" in \
		x86_64|aarch64) \
			EXTRA_CFLAGS="${EXTRA_CFLAGS:-} -fno-omit-frame-pointer -mno-omit-leaf-frame-pointer"; \
			;; \
		x86) ;; \
		*) EXTRA_CFLAGS="${EXTRA_CFLAGS:-} -fno-omit-frame-pointer"; \
	esac; \
	make -j "$nproc" \
		"EXTRA_CFLAGS=${EXTRA_CFLAGS:-}" \
		"LDFLAGS=${LDFLAGS:-}"; \
	rm python; \
	make -j "$nproc" \
		"EXTRA_CFLAGS=${EXTRA_CFLAGS:-}" \
		"LDFLAGS=${LDFLAGS:--Wl},-rpath='\$\$ORIGIN/../lib'" \
		python; \
	make install; \
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
	find /usr/local -type f -executable -not \( -name '*tkinter*' \) -exec scanelf --needed --nobanner --format '%n#p' '{}' ';' \
		| tr ',' '\n' \
		| sort -u \
		| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
		| xargs -rt apk add --no-network --virtual .python-rundeps \
	; \
	apk del --no-network .build-deps; \
	export PYTHONDONTWRITEBYTECODE=1; \
	python3 --version; \
	pip3 --version

# make some useful symlinks that are expected to exist
RUN set -eux; \
	for src in idle3 pip3 pydoc3 python3 python3-config; do \
		dst="$(echo "$src" | tr -d 3)"; \
		[ -s "/usr/local/bin/$src" ]; \
		[ ! -e "/usr/local/bin/$dst" ]; \
		ln -svT "$src" "/usr/local/bin/$dst"; \
	done

CMD ["python3"]
