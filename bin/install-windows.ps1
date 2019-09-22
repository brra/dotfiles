function Install-Chocolatey
{
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingInvokeExpression", "", Justification="Trusting Chocolatey installer")]
  param()

  if (!$env:ChocolateyInstall) {
    Set-ExecutionPolicy Unrestricted -Scope CurrentUser -Force; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
  } else {
    Write-Output "Chocolatey is already installed"
  }
}

function Install-Packages
{
  $Packages =
    'chocolatey',
    'conemu',
    'git',
    'keepass',
    'notepadplusplus',
    'vscode'

  ForEach ($Package in $Packages)
  {
    choco install -y $Package
  }
}

function Install-VSCode-Extensions
{
  $Extensions =
    'mauve.terraform',
    'ms-azuretools.vscode-docker',
    'ms-python.python',
    'ms-vscode.powershell'

  ForEach ($Extension in $Extensions)
  {
    code --install-extension $Extension
  }
}

Install-Chocolatey
choco upgrade -y all
Install-Packages
Install-VSCode-Extensions
