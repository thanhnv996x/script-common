
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Unrestricted -Force
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

choco install -y git

choco install -y python --version=3.9.0

Start-Process msiexec.exe -Wait -ArgumentList '/i \"https://awscli.amazonaws.com/AWSCLIV2.msi\" /q'

\$env:ChocolateyInstall = Convert-Path \"\$((Get-Command choco).Path)\..\..\"
Import-Module \"\$env:ChocolateyInstall\helpers\chocolateyProfile.psm1\"

refreshenv

pip install -r  ./requirements.txt

cd C:/
git clone https://thanhnv9961:glpat-zEEumkGHhgwMHJndxNw4@gitlab.com/thanhnv996/ya-claims-encrypt.git YAClaims
cd YAClaims
