#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "apply-templates.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#

FROM mcr.microsoft.com/windows/servercore:ltsc2022

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# PATH isn't actually set in the Docker image, so we have to set it from within the container
RUN $newPath = ('C:\Python;C:\Python\Scripts;{0}' -f $env:PATH); \
	Write-Host ('Updating PATH: {0}' -f $newPath); \
	[Environment]::SetEnvironmentVariable('PATH', $newPath, [EnvironmentVariableTarget]::Machine); \
	Write-Host 'Complete.'
# doing this first to share cache across versions more aggressively

ENV PYTHON_VERSION 3.16.0a2
ENV PYTHON_SHA256 e604493562d97593a3456cc4c7e8483448176bf0d4e49d7d74d388dd433f28c7

RUN $url = 'https://www.python.org/ftp/python/3.16.0/python-3.16.0a2-amd64.zip'; \
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
