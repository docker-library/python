FROM buildpack-deps

RUN apt-get update && apt-get install -y curl procps

# remove several traces of debian python
RUN apt-get purge -y python python-minimal python2.7-minimal

# http://bugs.python.org/issue19846
# > At the moment, setting "LANG=C" on a Linux system *fundamentally breaks Python 3*, and that's not OK.
ENV LANG C.UTF-8

ENV PYTHON_VERSION 2.7.8

RUN mkdir -p /usr/src/python \
	&& curl -SL "https://www.python.org/ftp/python/$PYTHON_VERSION/Python-$PYTHON_VERSION.tar.xz" \
		| tar -xJC /usr/src/python --strip-components=1 \
	&& cd /usr/src/python \
	&& ./configure \
	&& make -j$(nproc) \
	&& make install \
	&& cd / \
	&& rm -rf /usr/src/python

# install "pip" and "virtualenv", since the vast majority of users of this image will want it
RUN curl -SL 'https://bootstrap.pypa.io/get-pip.py' | python2
RUN pip install virtualenv

CMD ["python2"]
