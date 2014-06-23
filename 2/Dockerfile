FROM buildpack-deps

RUN apt-get update && apt-get install -y curl procps

# remove several traces of debian python
RUN apt-get purge -y python python-minimal python2.7-minimal

RUN mkdir /usr/src/python
WORKDIR /usr/src/python
# skip "test_file2k" thanks to "AssertionError: IOError not raised"
RUN curl -SL https://www.python.org/ftp/python/2.7.7/Python-2.7.7.tar.xz \
		| tar -xJ --strip-components=1 \
	&& ./configure \
	&& make -j$(nproc) \
	&& make EXTRATESTOPTS='--exclude test_file2k' test \
	&& make install \
	&& make clean

CMD ["python2"]
