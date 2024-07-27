Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Unrestricted -Force
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

choco install -y git

choco install -y python --version=3.9.0

Start-Process msiexec.exe -Wait -ArgumentList '/i \"https://awscli.amazonaws.com/AWSCLIV2.msi\" /q'

\$env:ChocolateyInstall = Convert-Path \"\$((Get-Command choco).Path)\..\..\"
Import-Module \"\$env:ChocolateyInstall\helpers\chocolateyProfile.psm1\"

refreshenv

git --version
python --version
aws --version

pip install beautifulsoup4
pip install selenium
pip install selenium-stealth
pip install opencv-python
pip install pyautogui
pip install Cython
pip install pandas
pip install xlrd
pip install openpyxl
pip install requests
pip install fake_useragent
pip install Pillow --upgrade
pip install webdriver_manager
pip install undetected_chromedriver
pip install psutil
pip install tkdesigner
pip install user_agent
pip install pywin32
pip install pytube
pip install --upgrade google-cloud-translate
pip install Eel
pip install chromedriver_autoinstaller
pip install google_auth_oauthlib
pip install google-api-python-client
pip install jsonpickle
pip install openpyxl
pip install aiohttp
pip install aiofiles
pip install pyquery
pip install js2py
pip install openai==0.28


cd C:/
git clone https://thanhnv9961:glpat-f-51NKzzTa-jyp54RDuV@gitlab.com/thanhnv996/yatranslator.git YAMasterTub
cd YAMasterTub
