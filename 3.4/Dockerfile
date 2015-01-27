FROM buildpack-deps:jessie

# remove several traces of debian python
RUN apt-get purge -y python.*

# http://bugs.python.org/issue19846
# > At the moment, setting "LANG=C" on a Linux system *fundamentally breaks Python 3*, and that's not OK.
ENV LANG C.UTF-8

ENV PYTHON_VERSION 3.4.2

#Keys from https://www.python.org/downloads/
RUN gpg --keyserver pool.sks-keyservers.net --recv-keys \
	0D96DF4D4110E5C43FBFB17F2D347EA6AA65421D \
	12EF3DC38047DA382D18A5B999CDEA9DA4135B38 \
	26DEA9D4613391EF3E25C9FF0A5B101836580288 \
	2BA0DB82515BBB9EFFAC71C5C9BE28DEE6DF025C \
	531F072D39700991925FED0C0EDDC5F26A45C816 \
	8417157EDBE73D9EAC1E539B126EB563A74B06BF \
	97FC712E4C024BBEA48A61ED3A5CA953F73C700D \
	C9B104B3DD3AA72D7CCB1066FB9921286F5E1540 \
	C01E1CAD5EA2C4F0B8E3571504C367C218ADD4FF \
	CBC547978A3964D14B9AB36A6AF053F07D9DC8D2 \
	DBBF2EEBF925FAADCF1F3FFFD9866941EA5BBD71 \
#Short version of the key, due to the fact that HKP keyservers do not support v3 fingerprints
	7123BC13ED9D77D5

RUN set -x \
	&& mkdir -p /usr/src/python \
	&& curl -SL "https://www.python.org/ftp/python/$PYTHON_VERSION/Python-$PYTHON_VERSION.tar.xz" -o "Python-$PYTHON_VERSION.tar.xz" \
	&& curl -SL "https://www.python.org/ftp/python/$PYTHON_VERSION/Python-$PYTHON_VERSION.tar.xz.asc" -o "Python-$PYTHON_VERSION.tar.xz.asc" \
	&& gpg --verify "Python-$PYTHON_VERSION.tar.xz.asc" \
	&& tar -xJC /usr/src/python --strip-components=1 -f "Python-$PYTHON_VERSION.tar.xz" \
	&& rm "Python-$PYTHON_VERSION.tar.xz"* \
	&& cd /usr/src/python \
	&& ./configure --enable-shared \
	&& make -j$(nproc) \
	&& make install \
	&& ldconfig \
	&& find /usr/local \
		\( -type d -a -name test -o -name tests \) \
		-o \( -type f -a -name '*.pyc' -o -name '*.pyo' \) \
		-exec rm -rf '{}' + \
	&& rm -rf /usr/src/python

# make some useful symlinks that are expected to exist
RUN cd /usr/local/bin \
	&& ln -s easy_install-3.4 easy_install \
	&& ln -s idle3 idle \
	&& ln -s pip3 pip \
	&& ln -s pydoc3 pydoc \
	&& ln -s python3 python \
	&& ln -s python-config3 python-config

CMD ["python3"]
