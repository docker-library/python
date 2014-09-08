FROM buildpack-deps

RUN apt-get update && apt-get install -y curl procps

# remove several traces of debian python
RUN apt-get purge -y python python-minimal python2.7-minimal

RUN mkdir /usr/src/python
WORKDIR /usr/src/python

ENV PYTHON_VERSION 2.7.8

RUN curl -SL "https://www.python.org/ftp/python/$PYTHON_VERSION/Python-$PYTHON_VERSION.tar.xz" \
		| tar -xJ --strip-components=1
# skip "test_file2k" thanks to "AssertionError: IOError not raised"
# skip "test_mhlib" because it fails on the hub in "test_listfolders" with "AssertionError: Lists differ: [] != ['deep', 'deep/f1', 'deep/f2',..."
RUN ./configure \
	&& make -j$(nproc) \
	&& make EXTRATESTOPTS='--exclude test_file2k test_mhlib' test \
	&& make install \
	&& make clean

# install "pip" and "virtualenv", since the vast majority of users of this image will want it
RUN curl -SL 'https://bootstrap.pypa.io/get-pip.py' | python2 && pip install virtualenv

CMD ["python2"]
