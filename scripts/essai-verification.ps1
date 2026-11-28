# Usage: essai-verification.ps1 <install.ps1>
# Needs gpg and a provenance tool (gh signed in, or cosign): the genuine release installs with both checks
# passed, a substituted archive and a modified SHA256SUMS are refused.
param([Parameter(Mandatory)][string]$script)
$ErrorActionPreference = 'Stop'

$script = (Resolve-Path $script).Path
$version = (Invoke-RestMethod https://packages.bonk-os.app/version.txt).Trim()
$release = "https://github.com/FantasmaGlad/Bonk/releases/download/v$version"
$miroir = "https://gitlab.com/api/v4/projects/89566133/packages/generic/bonk/$version"
$travail = Join-Path ([IO.Path]::GetTempPath()) ([IO.Path]::GetRandomFileName())
New-Item -ItemType Directory -Path $travail | Out-Null

function Invoke-Cas([string]$remplacements, [string[]]$absents = @()) {
  $serveur = Start-Process python -ArgumentList (@("$PSScriptRoot\release-locale.py", '8089', $release, $remplacements) + $absents) -PassThru -NoNewWindow
  Start-Sleep -Seconds 2
  try {
    $env:BONK_RELEASE_URL = 'http://127.0.0.1:8089'
    $sortie = & pwsh -NoProfile -File $script *>&1 | Out-String
    [pscustomobject]@{ Code = $LASTEXITCODE; Sortie = $sortie }
  } finally {
    Remove-Item Env:BONK_RELEASE_URL
    Stop-Process $serveur -Force
  }
}

function Assert-Sortie($cas, [string]$attendu, [string]$nom) {
  if (-not $cas.Sortie.Contains($attendu)) { throw "« $attendu » absent de la sortie de $nom :`n$($cas.Sortie)" }
}

try {
  # The signature of releases published before it was joined on GitHub lives on the GitLab mirror.
  $vraie = New-Item -ItemType Directory -Path (Join-Path $travail 'vraie')
  Invoke-WebRequest "$release/SHA256SUMS" -OutFile "$vraie\SHA256SUMS" -UseBasicParsing
  foreach ($f in 'SHA256SUMS.asc', 'bonk-release-key.asc') {
    try { Invoke-WebRequest "$release/$f" -OutFile "$vraie\$f" -UseBasicParsing }
    catch { Invoke-WebRequest "$miroir/$f" -OutFile "$vraie\$f" -UseBasicParsing }
  }

  $cas = Invoke-Cas $vraie
  if ($cas.Code -ne 0) { throw "la vraie release est refusée :`n$($cas.Sortie)" }
  Assert-Sortie $cas 'signed by the Bonk release key' 'la vraie release'
  Assert-Sortie $cas 'built by the release workflow' 'la vraie release'
  $archive = [regex]::Match($cas.Sortie, '(bonk-cli-\S+\.zip) built by').Groups[1].Value
  Write-Output "OK vraie release : signature et provenance de $archive vérifiées"

  $fausse = New-Item -ItemType Directory -Path (Join-Path $travail 'archive')
  Invoke-WebRequest "$release/$archive" -OutFile "$fausse\$archive" -UseBasicParsing
  [IO.File]::AppendAllText("$fausse\$archive", 'x')
  $somme = (Get-FileHash "$fausse\$archive" -Algorithm SHA256).Hash.ToLower()
  [IO.File]::WriteAllText("$fausse\SHA256SUMS", "$somme  $archive`n")
  $cas = Invoke-Cas $fausse @('SHA256SUMS.asc')
  if ($cas.Code -eq 0) { throw "archive substituée installée :`n$($cas.Sortie)" }
  Assert-Sortie $cas 'has no provenance attestation' "l'archive substituée"
  Write-Output 'OK archive substituée, SHA256SUMS recalculé : refusée'

  $sommes = New-Item -ItemType Directory -Path (Join-Path $travail 'sommes')
  Copy-Item "$vraie\SHA256SUMS.asc", "$vraie\bonk-release-key.asc" $sommes
  $texte = [IO.File]::ReadAllText("$vraie\SHA256SUMS")
  $premier = if ($texte[0] -eq '0') { '1' } else { '0' }
  [IO.File]::WriteAllText("$sommes\SHA256SUMS", $premier + $texte.Substring(1))
  $cas = Invoke-Cas $sommes
  if ($cas.Code -eq 0) { throw "SHA256SUMS modifié accepté :`n$($cas.Sortie)" }
  Assert-Sortie $cas 'is not signed by the Bonk release key' 'SHA256SUMS modifié'
  Write-Output 'OK SHA256SUMS modifié sous une vraie signature : refusé'
} finally {
  Remove-Item $travail -Recurse -Force
}
