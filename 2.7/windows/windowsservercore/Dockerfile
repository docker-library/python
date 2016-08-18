FROM microsoft/windowsservercore

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop';"]

ENV PYTHON_VERSION 2.7.12
ENV PYTHON_RELEASE 2.7.12

# if this is called "PIP_VERSION", pip explodes with "ValueError: invalid truth value '<VERSION>'"
ENV PYTHON_PIP_VERSION 8.1.2

RUN $url = ('https://www.python.org/ftp/python/{0}/python-{1}.amd64.msi' -f $env:PYTHON_RELEASE, $env:PYTHON_VERSION); \
	Write-Host ('Downloading {0} ...' -f $url); \
	(New-Object System.Net.WebClient).DownloadFile($url, 'python.msi'); \
	\
	Write-Host 'Installing ...'; \
# https://www.python.org/download/releases/2.4/msi/
	Start-Process msiexec -Wait \
		-ArgumentList @( \
			'/i', \
			'python.msi', \
			'/quiet', \
			'/qn', \
			'TARGETDIR=C:\Python', \
			'ALLUSERS=1', \
			'ADDLOCAL=DefaultFeature,Extensions,TclTk,Tools,PrependPath' \
		); \
	\
# the installer updated PATH, so we should refresh our local value
	$env:PATH = [Environment]::GetEnvironmentVariable('PATH', [EnvironmentVariableTarget]::Machine); \
	\
	Write-Host 'Verifying install ...'; \
	Write-Host '  python --version'; python --version; \
	\
	Write-Host 'Removing ...'; \
	Remove-Item python.msi -Force; \
	\
	$pipInstall = ('pip=={0}' -f $env:PYTHON_PIP_VERSION); \
	Write-Host ('Installing {0} ...' -f $pipInstall); \
	(New-Object System.Net.WebClient).DownloadFile('https://bootstrap.pypa.io/get-pip.py', 'get-pip.py'); \
	python get-pip.py $pipInstall; \
	Remove-Item get-pip.py -Force; \
	\
	Write-Host 'Verifying pip install ...'; \
	pip --version; \
	\
	Write-Host 'Complete.';

# install "virtualenv", since the vast majority of users of this image will want it
RUN pip install --no-cache-dir virtualenv

CMD ["python"]
