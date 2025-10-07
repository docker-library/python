#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "apply-templates.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#

FROM alpine:3.21

# ensure local python is preferred over distribution python
ENV PATH /usr/local/bin:$PATH

# runtime dependencies
RUN set -eux; \
	apk add --no-cache \
		ca-certificates \
		tzdata \
	;

ENV PYTHON_VERSION 3.14.0
ENV PYTHON_SHA256 2299dae542d395ce3883aca00d3c910307cd68e0b2f7336098c8e7b7eee9f3e9

RUN set -eux; \
	\
	apk add --no-cache --virtual .build-deps \
		gnupg \
		tar \
		xz \
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
		sqlite-dev \
		tcl-dev \
		tk \
		tk-dev \
		util-linux-dev \
		xz-dev \
		zlib-dev \
# hack hack hack: https://github.com/python/cpython/blob/3.13/Tools/jit/README.md
		clang19 \
		llvm19 \
		python3 \
	; \
	\
	wget -O python.tar.xz "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz"; \
	echo "$PYTHON_SHA256 *python.tar.xz" | sha256sum -c -; \
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
		$(test "${gnuArch%%-*}" != 'riscv64' && echo '--with-lto') \
		--with-ensurepip \
# https://github.com/docker-library/python/issues/947
		--disable-gil \
		--enable-experimental-jit=yes \
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

# make some useful symlinks that are expected to exist ("/usr/local/bin/python" and friends)
RUN set -eux; \
	for src in idle3 pip3 pydoc3 python3 python3-config; do \
		dst="$(echo "$src" | tr -d 3)"; \
		[ -s "/usr/local/bin/$src" ]; \
		[ ! -e "/usr/local/bin/$dst" ]; \
		ln -svT "$src" "/usr/local/bin/$dst"; \
	done

CMD ["python3"]
