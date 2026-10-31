# Installe la version de Bonk sans fenêtre pour cet utilisateur, sans droits d'administrateur.
# Usage : irm https://packages.bonk-os.app/install.ps1 | iex
$ErrorActionPreference = 'Stop'

$cible = switch ($env:PROCESSOR_ARCHITECTURE) {
  'AMD64' { 'windows-x86_64' }
  'ARM64' { 'windows-aarch64' }
  'x86' { 'windows-i686' }
  default { throw "Unsupported system: $env:PROCESSOR_ARCHITECTURE" }
}
$version = (Invoke-RestMethod https://packages.bonk-os.app/version.txt).Trim()
$dossier = "bonk-cli-$version-$cible"
$base = "https://github.com/FantasmaGlad/Bonk/releases/download/v$version"
$travail = Join-Path ([IO.Path]::GetTempPath()) ([IO.Path]::GetRandomFileName())
New-Item -ItemType Directory -Path $travail | Out-Null
try {
  $archive = Join-Path $travail "$dossier.zip"
  Invoke-WebRequest "$base/$dossier.zip" -OutFile $archive -UseBasicParsing
  # GitHub sert ce fichier comme binaire : sa réponse directe serait des octets, jamais du texte.
  $empreintes = Join-Path $travail 'SHA256SUMS'
  Invoke-WebRequest "$base/SHA256SUMS" -OutFile $empreintes -UseBasicParsing
  $ligne = Get-Content $empreintes | Where-Object { $_ -match "\s\*?$([regex]::Escape("$dossier.zip"))\s*$" }
  if (-not $ligne) { throw "No checksum for $dossier.zip" }
  $attendue = ($ligne -split '\s+')[0]
  if ((Get-FileHash $archive -Algorithm SHA256).Hash -ne $attendue.ToUpper()) { throw "Checksum mismatch: $dossier.zip" }
  Expand-Archive $archive -DestinationPath $travail
  $destination = Join-Path $env:LOCALAPPDATA 'Programs\Bonk'
  New-Item -ItemType Directory -Force -Path $destination | Out-Null
  Copy-Item (Join-Path $travail "$dossier\bonk.exe") $destination -Force
} finally {
  Remove-Item $travail -Recurse -Force
}
$chemins = [Environment]::GetEnvironmentVariable('Path', 'User')
if (($chemins -split ';') -notcontains $destination) {
  [Environment]::SetEnvironmentVariable('Path', "$chemins;$destination", 'User')
  Write-Output 'Open a new terminal to use bonk.'
}
& (Join-Path $destination 'bonk.exe') --version
