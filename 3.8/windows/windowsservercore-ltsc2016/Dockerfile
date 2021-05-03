#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "update.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#

FROM mcr.microsoft.com/windows/servercore:ltsc2016

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# https://github.com/docker-library/python/pull/557
ENV PYTHONIOENCODING UTF-8

ENV PYTHON_VERSION 3.8.10
ENV PYTHON_RELEASE 3.8.10

RUN $url = ('https://www.python.org/ftp/python/{0}/python-{1}-amd64.exe' -f $env:PYTHON_RELEASE, $env:PYTHON_VERSION); \
	Write-Host ('Downloading {0} ...' -f $url); \
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; \
	Invoke-WebRequest -Uri $url -OutFile 'python.exe'; \
	\
	Write-Host 'Installing ...'; \
# https://docs.python.org/3/using/windows.html#installing-without-ui
	$exitCode = (Start-Process python.exe -Wait -NoNewWindow -PassThru \
		-ArgumentList @( \
			'/quiet', \
			'InstallAllUsers=1', \
			'TargetDir=C:\Python', \
			'PrependPath=1', \
			'Shortcuts=0', \
			'Include_doc=0', \
			'Include_pip=0', \
			'Include_test=0' \
		) \
	).ExitCode; \
	if ($exitCode -ne 0) { \
		Write-Host ('Running python installer failed with exit code: {0}' -f $exitCode); \
		Get-ChildItem $env:TEMP | Sort-Object -Descending -Property LastWriteTime | Select-Object -First 1 | Get-Content; \
		exit $exitCode; \
	} \
	\
# the installer updated PATH, so we should refresh our local value
	$env:PATH = [Environment]::GetEnvironmentVariable('PATH', [EnvironmentVariableTarget]::Machine); \
	\
	Write-Host 'Verifying install ...'; \
	Write-Host '  python --version'; python --version; \
	\
	Write-Host 'Removing ...'; \
	Remove-Item python.exe -Force; \
	Remove-Item $env:TEMP/Python*.log -Force; \
	\
	Write-Host 'Complete.'

# if this is called "PIP_VERSION", pip explodes with "ValueError: invalid truth value '<VERSION>'"
ENV PYTHON_PIP_VERSION 21.1.1
# https://github.com/pypa/get-pip
ENV PYTHON_GET_PIP_URL https://github.com/pypa/get-pip/raw/1954f15b3f102ace496a34a013ea76b061535bd2/public/get-pip.py
ENV PYTHON_GET_PIP_SHA256 f499d76e0149a673fb8246d88e116db589afbd291739bd84f2cd9a7bca7b6993

RUN Write-Host ('Downloading get-pip.py ({0}) ...' -f $env:PYTHON_GET_PIP_URL); \
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; \
	Invoke-WebRequest -Uri $env:PYTHON_GET_PIP_URL -OutFile 'get-pip.py'; \
	Write-Host ('Verifying sha256 ({0}) ...' -f $env:PYTHON_GET_PIP_SHA256); \
	if ((Get-FileHash 'get-pip.py' -Algorithm sha256).Hash -ne $env:PYTHON_GET_PIP_SHA256) { \
		Write-Host 'FAILED!'; \
		exit 1; \
	}; \
	\
	Write-Host ('Installing pip=={0} ...' -f $env:PYTHON_PIP_VERSION); \
	python get-pip.py \
		--disable-pip-version-check \
		--no-cache-dir \
		('pip=={0}' -f $env:PYTHON_PIP_VERSION) \
	; \
	Remove-Item get-pip.py -Force; \
	\
	Write-Host 'Verifying pip install ...'; \
	pip --version; \
	\
	Write-Host 'Complete.'

CMD ["python"]
