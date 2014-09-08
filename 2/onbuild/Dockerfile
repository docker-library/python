FROM python:2

WORKDIR /usr/src/app
ONBUILD ADD requirements.txt /usr/src/app/requirements.txt
ONBUILD RUN pip install -r /app/requirements.txt
ONBUILD ADD . /usr/src/app
