FROM alpine:edge

RUN apk add -u --no-cache gnupg

# gpg: key F73C700D: public key "Larry Hastings <larry@hastings.org>" imported
RUN gpg --keyserver ha.pool.sks-keyservers.net --recv-keys 97FC712E4C024BBEA48A61ED3A5CA953F73C700D

ENV PYTHON_VERSION 3.5.1

# if this is called "PIP_VERSION", pip explodes with "ValueError: invalid truth value '<VERSION>'"
ENV PYTHON_PIP_VERSION 7.1.2

RUN set -x -e ;\
	build_deps=' \
		bzip2-dev \
		curl \
		gcc \
		libc-dev \
		libedit-dev \
		linux-headers \
		make \
		make \
		ncurses-dev \
		openssl-dev \
		sqlite-dev \
		zlib-dev \
		pax-utils \
	' \
	&& apk add --no-cache --virtual .build-deps  $build_deps \
	&& mkdir -p /usr/src/ \
	&& curl -SL "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz" -o python.tar.xz \
	&& curl -SL "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz.asc" -o python.tar.xz.asc \
	&& gpg --verify python.tar.xz.asc \
	&& tar -xJC /usr/src -f python.tar.xz \
	&& mv /usr/src/Python-${PYTHON_VERSION} /usr/src/python \
	&& rm python.tar.xz* \
	&& cd /usr/src/python \
	&& ./configure --enable-shared --enable-unicode=ucs4 \
	&& make -j$(getconf _NPROCESSORS_ONLN) \
	&& make install \
	&& pip3 install --no-cache-dir --upgrade --ignore-installed pip==$PYTHON_PIP_VERSION \
	&& find /usr/local \
		\( -type d -a -name test -o -name tests \) \
		-o \( -type f -a -name '*.pyc' -o -name '*.pyo' \) \
		-exec rm -rf '{}' + \
	&& rundeps=$(scanelf -R -n --nobanner /usr/local/  \
		| awk '{gsub(/,/,"\n",$2); print $2}' \
		| sort -u | sed 's/^/so:/' | while read dep; do \
			apk info --installed -q $dep && echo $dep; \
		done | sort -u) \
	&& apk add --virtual .python-rundeps $rundeps \
	&& apk del .build-deps gnupg \
	&& rm -rf /usr/src/python

# make some useful symlinks that are expected to exist
RUN cd /usr/local/bin \
	&& ln -s easy_install-3.5 easy_install \
	&& ln -s idle3 idle \
	&& ln -s pydoc3 pydoc \
	&& ln -s python3 python \
	&& ln -s python-config3 python-config

CMD ["python3"]
