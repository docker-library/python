FROM buildpack-deps:jessie

# remove several traces of debian python
RUN apt-get purge -y python.*

# http://bugs.python.org/issue19846
# > At the moment, setting "LANG=C" on a Linux system *fundamentally breaks Python 3*, and that's not OK.
ENV LANG C.UTF-8

# gpg: key 18ADD4FF: public key "Benjamin Peterson <benjamin@python.org>" imported (for py27)
RUN gpg --keyserver ha.pool.sks-keyservers.net --recv-keys C01E1CAD5EA2C4F0B8E3571504C367C218ADD4FF
# gpg: key 36580288: public key "Georg Brandl (Python release signing key) <georg@python.org>" imported (for py33)
RUN gpg --keyserver ha.pool.sks-keyservers.net --recv-keys 26DEA9D4613391EF3E25C9FF0A5B101836580288
# gpg: key F73C700D: public key "Larry Hastings <larry@hastings.org>" imported (for py34,py35)
RUN gpg --keyserver ha.pool.sks-keyservers.net --recv-keys 97FC712E4C024BBEA48A61ED3A5CA953F73C700D

# if this is called "PIP_VERSION", pip explodes with "ValueError: invalid truth value '<VERSION>'"
ENV PYTHON_PIP_VERSION 7.1.2

ENV PYTHON_VERSION 2.7.11

RUN set -x \
	&& mkdir -p /usr/src/python \
	&& curl -SL "https://www.python.org/ftp/python/$PYTHON_VERSION/Python-$PYTHON_VERSION.tar.xz" -o python.tar.xz \
	&& curl -SL "https://www.python.org/ftp/python/$PYTHON_VERSION/Python-$PYTHON_VERSION.tar.xz.asc" -o python.tar.xz.asc \
	&& gpg --verify python.tar.xz.asc \
	&& tar -xJC /usr/src/python --strip-components=1 -f python.tar.xz \
	&& rm python.tar.xz* \
	&& cd /usr/src/python \
	&& ./configure --enable-shared --enable-unicode=ucs4 \
	&& make -j$(nproc) \
	&& make install \
	&& ldconfig \
	&& curl -SL 'https://bootstrap.pypa.io/get-pip.py' | python2 \
	&& pip install --no-cache-dir --upgrade pip==$PYTHON_PIP_VERSION \
	&& find /usr/local \
		\( -type d -a -name test -o -name tests \) \
		-o \( -type f -a -name '*.pyc' -o -name '*.pyo' \) \
		-exec rm -rf '{}' + \
	&& rm -rf /usr/src/python

ENV PYTHON_VERSION 3.3.6

RUN set -x \
	&& mkdir -p /usr/src/python \
	&& curl -SL "https://www.python.org/ftp/python/$PYTHON_VERSION/Python-$PYTHON_VERSION.tar.xz" -o python.tar.xz \
	&& curl -SL "https://www.python.org/ftp/python/$PYTHON_VERSION/Python-$PYTHON_VERSION.tar.xz.asc" -o python.tar.xz.asc \
	&& gpg --verify python.tar.xz.asc \
	&& tar -xJC /usr/src/python --strip-components=1 -f python.tar.xz \
	&& rm python.tar.xz* \
	&& cd /usr/src/python \
	&& ./configure --enable-shared --enable-unicode=ucs4 \
	&& make -j$(nproc) \
	&& make install \
	&& ldconfig \
	&& curl -SL 'https://bootstrap.pypa.io/get-pip.py' | python3 \
	&& pip install --no-cache-dir --upgrade pip==$PYTHON_PIP_VERSION \
	&& find /usr/local \
		\( -type d -a -name test -o -name tests \) \
		-o \( -type f -a -name '*.pyc' -o -name '*.pyo' \) \
		-exec rm -rf '{}' + \
	&& rm -rf /usr/src/python

ENV PYTHON_VERSION 3.4.3

RUN set -x \
	&& mkdir -p /usr/src/python \
	&& curl -SL "https://www.python.org/ftp/python/$PYTHON_VERSION/Python-$PYTHON_VERSION.tar.xz" -o python.tar.xz \
	&& curl -SL "https://www.python.org/ftp/python/$PYTHON_VERSION/Python-$PYTHON_VERSION.tar.xz.asc" -o python.tar.xz.asc \
	&& gpg --verify python.tar.xz.asc \
	&& tar -xJC /usr/src/python --strip-components=1 -f python.tar.xz \
	&& rm python.tar.xz* \
	&& cd /usr/src/python \
	&& ./configure --enable-shared --enable-unicode=ucs4 \
	&& make -j$(nproc) \
	&& make install \
	&& ldconfig \
	&& pip3 install --no-cache-dir --upgrade pip==$PYTHON_PIP_VERSION \
	&& find /usr/local \
		\( -type d -a -name test -o -name tests \) \
		-o \( -type f -a -name '*.pyc' -o -name '*.pyo' \) \
		-exec rm -rf '{}' + \
	&& rm -rf /usr/src/python

ENV PYTHON_VERSION 3.5.1

RUN set -x \
	&& mkdir -p /usr/src/python \
	&& curl -SL "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz" -o python.tar.xz \
	&& curl -SL "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz.asc" -o python.tar.xz.asc \
	&& gpg --verify python.tar.xz.asc \
	&& tar -xJC /usr/src/python --strip-components=1 -f python.tar.xz \
	&& rm python.tar.xz* \
	&& cd /usr/src/python \
	&& ./configure --enable-shared --enable-unicode=ucs4 \
	&& make -j$(nproc) \
	&& make install \
	&& ldconfig \
	&& pip3 install --no-cache-dir --upgrade --ignore-installed pip==$PYTHON_PIP_VERSION \
	&& find /usr/local \
		\( -type d -a -name test -o -name tests \) \
		-o \( -type f -a -name '*.pyc' -o -name '*.pyo' \) \
		-exec rm -rf '{}' + \
	&& rm -rf /usr/src/python

# make some useful symlinks that are expected to exist (for latest python3 version only)
RUN cd /usr/local/bin \
	&& ln -sf easy_install-3.5 easy_install \
	&& ln -sf idle3 idle \
	&& ln -sf pydoc3 pydoc \
	&& ln -sf python3 python \
	&& ln -sf python-config3 python-config

CMD ["python3"]
