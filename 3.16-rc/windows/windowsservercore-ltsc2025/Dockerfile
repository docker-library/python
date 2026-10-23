#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "apply-templates.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#

FROM mcr.microsoft.com/windows/servercore:ltsc2025

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# PATH isn't actually set in the Docker image, so we have to set it from within the container
RUN $newPath = ('C:\Python;C:\Python\Scripts;{0}' -f $env:PATH); \
	Write-Host ('Updating PATH: {0}' -f $newPath); \
	[Environment]::SetEnvironmentVariable('PATH', $newPath, [EnvironmentVariableTarget]::Machine); \
	Write-Host 'Complete.'
# doing this first to share cache across versions more aggressively

ENV PYTHON_VERSION 3.16.0a1
ENV PYTHON_SHA256 d70c353262f6a2ccd50cd5aa9273e22bc217a75d9ce1855b07b83fc2e6296454

RUN $url = 'https://www.python.org/ftp/python/3.16.0/python-3.16.0a1-amd64.zip'; \
	Write-Host ('Downloading {0} ...' -f $url); \
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; \
	Invoke-WebRequest -Uri $url -OutFile 'python.zip'; \
	\
	Write-Host ('Verifying sha256 ({0}) ...' -f $env:PYTHON_SHA256); \
	if ((Get-FileHash python.zip -Algorithm sha256).Hash -ne $env:PYTHON_SHA256) { \
		Write-Host 'FAILED!'; \
		exit 1; \
	}; \
	\
	Write-Host 'Expanding ...'; \
	Expand-Archive python.zip -DestinationPath C:\Python\; \
	\
	Write-Host 'Removing ...'; \
	Remove-Item python.zip -Force; \
	\
	Write-Host 'Verifying install ("python --version") ...'; \
	python --version; \
	\
	$env:PYTHONDONTWRITEBYTECODE = '1'; \
	\
	Write-Host 'Re-Installing pip ...'; \
	# remove zip-provided pip so that we can reinstall and get the exe in c:\Python\Scripts
	Remove-Item -Recurse C:\Python\Lib\site-packages\pip; \
	Remove-Item -Recurse C:\Python\Lib\site-packages\pip-*; \
	# install pip again
	python -m ensurepip --default-pip; \
	\
	Write-Host 'Verifying pip install ...'; \
	pip --version; \
	\
	Write-Host 'Complete.'

CMD ["python"]
