#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "apply-templates.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#

FROM alpine:3.22

# ensure local python is preferred over distribution python
ENV PATH /usr/local/bin:$PATH

# ensure the GIL stays enabled-by-default (even though we supply "--disable-gil" so that the "freethreading" mode is supported by our binaries)
# https://docs.python.org/3/using/cmdline.html#envvar-PYTHON_GIL
ENV PYTHON_GIL 1
# (we install a small wrapper script with the conventional "python3.13t" name to provide so-called "freethreading" behavior in a way that matches the current-as-of-2025 ecosystem conventions: https://docs.python.org/3.13/whatsnew/3.13.html#free-threaded-cpython)

# runtime dependencies
RUN set -eux; \
	apk add --no-cache \
		ca-certificates \
		tzdata \
	;

ENV GPG_KEY 7169605F62C751356D054A26A821E680E5FA6305
ENV PYTHON_VERSION 3.13.9
ENV PYTHON_SHA256 ed5ef34cda36cfa2f3a340f07cac7e7814f91c7f3c411f6d3562323a866c5c66

RUN set -eux; \
	\
	apk add --no-cache --virtual .build-deps \
		bluez-dev \
		bzip2-dev \
		dpkg-dev dpkg \
		findutils \
		gcc \
		gdbm-dev \
		gnupg \
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
		sqlite-dev \
		tar \
		tcl-dev \
		tk \
		tk-dev \
		util-linux-dev \
		xz \
		xz-dev \
		zlib-dev \
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
		--disable-gil \
		--enable-loadable-sqlite-extensions \
		--enable-option-checking=fatal \
		--enable-shared \
		$(test "${gnuArch%%-*}" != 'riscv64' && echo '--with-lto') \
		--with-ensurepip \
	; \
	nproc="$(nproc)"; \
# set thread stack size to 1MB so we don't segfault before we hit sys.getrecursionlimit()
# https://github.com/alpinelinux/aports/commit/2026e1259422d4e0cf92391ca2d3844356c649d0
	EXTRA_CFLAGS="-DTHREAD_STACK_SIZE=0x100000"; \
	LDFLAGS="${LDFLAGS:--Wl},--strip-all"; \
		arch="$(apk --print-arch)"; \
# https://docs.python.org/3.12/howto/perf_profiling.html
# https://github.com/docker-library/python/pull/1000#issuecomment-2597021615
		case "$arch" in \
			x86_64|aarch64) \
				# only add "-mno-omit-leaf" on arches that support it
				# https://gcc.gnu.org/onlinedocs/gcc-14.2.0/gcc/x86-Options.html#index-momit-leaf-frame-pointer-2
				# https://gcc.gnu.org/onlinedocs/gcc-14.2.0/gcc/AArch64-Options.html#index-momit-leaf-frame-pointer
				EXTRA_CFLAGS="${EXTRA_CFLAGS:-} -fno-omit-frame-pointer -mno-omit-leaf-frame-pointer"; \
				;; \
			x86) \
				# don't enable frame-pointers on 32bit x86 due to performance drop.
				;; \
			*) \
				# other arches don't support "-mno-omit-leaf"
				EXTRA_CFLAGS="${EXTRA_CFLAGS:-} -fno-omit-frame-pointer"; \
				;; \
		esac; \
	make -j "$nproc" \
		"EXTRA_CFLAGS=${EXTRA_CFLAGS:-}" \
		"LDFLAGS=${LDFLAGS:-}" \
	; \
# https://github.com/docker-library/python/issues/784
# prevent accidental usage of a system installed libpython of the same version
	rm python; \
	make -j "$nproc" \
		"EXTRA_CFLAGS=${EXTRA_CFLAGS:-}" \
		"LDFLAGS=${LDFLAGS:--Wl},-rpath='\$\$ORIGIN/../lib'" \
		python \
	; \
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
	\
	find /usr/local -type f -executable -not \( -name '*tkinter*' \) -exec scanelf --needed --nobanner --format '%n#p' '{}' ';' \
		| tr ',' '\n' \
		| sort -u \
		| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
		| xargs -rt apk add --no-network --virtual .python-rundeps \
	; \
	apk del --no-network .build-deps; \
	\
	export PYTHONDONTWRITEBYTECODE=1; \
	python3 --version; \
	pip3 --version

RUN set -eux; \
# make conventional "python3.13t" style wrappers (https://docs.python.org/3.13/whatsnew/3.13.html#free-threaded-cpython)
	for exe in /usr/local/bin/python3*; do \
		bin="$(basename "$exe")"; \
# ignore "python*-config"
		[ "${bin%-config}" = "$bin" ] || continue; \
# ignore existing "python*t" binaries (these are because we compile with --disable-gil)
		[ "${bin%t}" = "$bin" ] || continue; \
		printf '#!/usr/bin/env sh\nset -eu\nexport PYTHON_GIL=0\nexec "%s" "$@"\n' "$bin" > "${exe}t"; \
		chmod +x "${exe}t"; \
		"${exe}" -c 'import sys; assert(sys._is_gil_enabled())'; \
		"${exe}t" -c 'import sys; assert(not sys._is_gil_enabled())'; \
	done
# TODO THIS IS NOT A TENABLE LONG-TERM SOLUTION AS OUR BUILDS ARE NO LONGER ABI-COMPATIBLE, DESPITE THE POSSIBILITY THAT THEY MIGHT BE THAT'S SEMI-IMPLIED IN "Importing C extensions that don’t use these mechanisms will cause the GIL to be enabled" (https://docs.python.org/3.13/whatsnew/3.13.html#free-threaded-cpython)

# make some useful symlinks that are expected to exist ("/usr/local/bin/python" and friends)
RUN set -eux; \
	for src in idle3 pip3 pydoc3 python3 python3-config; do \
		dst="$(echo "$src" | tr -d 3)"; \
		[ -s "/usr/local/bin/$src" ]; \
		[ ! -e "/usr/local/bin/$dst" ]; \
		ln -svT "$src" "/usr/local/bin/$dst"; \
	done

CMD ["python3"]
