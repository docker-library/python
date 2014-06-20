FROM buildpack-deps

RUN apt-get update && apt-get install -y curl procps

# remove several traces of debian python
RUN apt-get purge -y python python-minimal python2.7-minimal

RUN mkdir /usr/src/python
WORKDIR /usr/src/python
RUN curl -SL https://www.python.org/ftp/python/3.4.1/Python-3.4.1.tar.xz \
		| tar -xJ --strip-components=1 \
	&& ./configure \
	&& make -j$(nproc) \
	&& make -j$(nproc) test \
	&& make install \
	&& make clean

# make some useful symlinks that are expected to exist
RUN cd /usr/local/bin \
	&& ln -s easy_install-3.4 easy_install \
	&& ln -s idle3 idle \
	&& ln -s pip3 pip \
	&& ln -s pydoc3 pydoc \
	&& ln -s python3 python \
	&& ln -s python-config3 python-config

CMD ["python"]
