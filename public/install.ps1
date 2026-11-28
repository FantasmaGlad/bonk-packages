# Usage: irm https://packages.bonk-os.app/install.ps1 | iex
$ErrorActionPreference = 'Stop'

$depot = 'FantasmaGlad/Bonk'
$cleRelease = '9F67B75803CE75260FB0D8952F20472E7865EDF1'
$emetteur = 'https://token.actions.githubusercontent.com'

function Test-Outil([string]$nom) { [bool](Get-Command $nom -ErrorAction SilentlyContinue) }

# Windows PowerShell turns the standard error of a native command into a terminating error under Stop.
function Invoke-Outil([string]$nom, [string[]]$arguments) {
  $ErrorActionPreference = 'Continue'
  $sortie = & $nom @arguments 2> $null
  [pscustomobject]@{ Code = $LASTEXITCODE; Sortie = @($sortie) }
}

function Confirm-Signature([string]$travail, [string]$base, [string]$version) {
  if (-not (Test-Outil gpg)) {
    Write-Warning "gpg is missing: the signature of SHA256SUMS by the Bonk release key $cleRelease was not checked."
    return
  }
  $signature = Join-Path $travail 'SHA256SUMS.asc'
  $cle = Join-Path $travail 'cle.asc'
  try {
    Invoke-WebRequest "$base/SHA256SUMS.asc" -OutFile $signature -UseBasicParsing
    Invoke-WebRequest "$base/bonk-release-key.asc" -OutFile $cle -UseBasicParsing
  } catch {
    Write-Warning "Bonk $version has no signature of SHA256SUMS: the signature was not checked."
    return
  }
  $gnupg = Join-Path $travail 'gnupg'
  New-Item -ItemType Directory -Path $gnupg | Out-Null
  Invoke-Outil gpg @('--homedir', $gnupg, '--batch', '--quiet', '--import', $cle) | Out-Null
  $etat = Invoke-Outil gpg @('--homedir', $gnupg, '--batch', '--status-fd', '1', '--verify', $signature, (Join-Path $travail 'SHA256SUMS'))
  Invoke-Outil gpgconf @('--homedir', $gnupg, '--kill', 'all') | Out-Null
  # VALIDSIG ends with the fingerprint of the primary key that made the signature.
  if (-not ($etat.Sortie | Where-Object { $_ -match "^\[GNUPG:\] VALIDSIG .* $cleRelease$" })) {
    throw "SHA256SUMS of Bonk $version is not signed by the Bonk release key $cleRelease."
  }
  Write-Output "SHA256SUMS signed by the Bonk release key $cleRelease."
}

function Test-AttestationCosign([string]$travail, [string]$archive, [string]$version) {
  $empreinte = (Get-FileHash $archive -Algorithm SHA256).Hash.ToLower()
  try {
    $reponse = Invoke-RestMethod "https://api.github.com/repos/$depot/attestations/sha256:$empreinte"
  } catch {
    return $false
  }
  $identite = "https://github.com/$depot/.github/workflows/binaires.yml@refs/tags/v$version"
  $bundle = Join-Path $travail 'bundle.json'
  foreach ($attestation in $reponse.attestations) {
    [IO.File]::WriteAllText($bundle, ($attestation.bundle | ConvertTo-Json -Depth 100 -Compress))
    $resultat = Invoke-Outil cosign @('verify-blob-attestation', '--bundle', $bundle, '--new-bundle-format',
      '--certificate-identity', $identite, '--certificate-oidc-issuer', $emetteur,
      '--type', 'https://slsa.dev/provenance/v1', $archive)
    if ($resultat.Code -eq 0) { return $true }
  }
  $false
}

function Confirm-Provenance([string]$travail, [string]$archive, [string]$version) {
  $nom = Split-Path $archive -Leaf
  $refus = "$nom has no provenance attestation from the release workflow of Bonk $version."
  if ((Test-Outil gh) -and (Invoke-Outil gh @('auth', 'status')).Code -eq 0) {
    $resultat = Invoke-Outil gh @('attestation', 'verify', $archive, '--repo', $depot,
      '--signer-workflow', "$depot/.github/workflows/binaires.yml", '--source-ref', "refs/tags/v$version")
    if ($resultat.Code -ne 0) { throw $refus }
  } elseif (Test-Outil cosign) {
    if (-not (Test-AttestationCosign $travail $archive $version)) { throw $refus }
  } else {
    Write-Warning "neither gh signed in (gh auth login) nor cosign is installed: the provenance of $nom was not checked, only its SHA-256. By hand: gh attestation verify $nom --repo $depot"
    return
  }
  Write-Output "$nom built by the release workflow of $depot at v$version."
}

$cible = switch ($env:PROCESSOR_ARCHITECTURE) {
  'AMD64' { 'windows-x86_64' }
  'ARM64' { 'windows-aarch64' }
  'x86' { 'windows-i686' }
  default { throw "Unsupported system: $env:PROCESSOR_ARCHITECTURE" }
}
$version = (Invoke-RestMethod https://packages.bonk-os.app/version.txt).Trim()
$dossier = "bonk-cli-$version-$cible"
$base = if ($env:BONK_RELEASE_URL) { $env:BONK_RELEASE_URL } else { "https://github.com/$depot/releases/download/v$version" }
$travail = Join-Path ([IO.Path]::GetTempPath()) ([IO.Path]::GetRandomFileName())
New-Item -ItemType Directory -Path $travail | Out-Null
try {
  # GitHub serves this file as binary: its direct answer would be bytes, never text.
  $empreintes = Join-Path $travail 'SHA256SUMS'
  Invoke-WebRequest "$base/SHA256SUMS" -OutFile $empreintes -UseBasicParsing
  Confirm-Signature $travail $base $version
  $ligne = Get-Content $empreintes | Where-Object { $_ -match "\s\*?$([regex]::Escape("$dossier.zip"))\s*$" }
  if (-not $ligne) { throw "Bonk $version has no build for $cible." }
  $attendue = ($ligne -split '\s+')[0]
  $archive = Join-Path $travail "$dossier.zip"
  Invoke-WebRequest "$base/$dossier.zip" -OutFile $archive -UseBasicParsing
  if ((Get-FileHash $archive -Algorithm SHA256).Hash -ne $attendue.ToUpper()) { throw "$dossier.zip does not match its SHA-256 in SHA256SUMS." }
  Confirm-Provenance $travail $archive $version
  Expand-Archive $archive -DestinationPath $travail
  $destination = Join-Path $env:LOCALAPPDATA 'Programs\Bonk'
  New-Item -ItemType Directory -Force -Path $destination | Out-Null
  Copy-Item (Join-Path $travail "$dossier\bonk.exe") $destination -Force
} finally {
  Remove-Item $travail -Recurse -Force
}
$chemins = [Environment]::GetEnvironmentVariable('Path', 'User')
if (($chemins -split ';') -notcontains $destination) {
  $nouveaux = if ($chemins) { "$chemins;$destination" } else { $destination }
  [Environment]::SetEnvironmentVariable('Path', $nouveaux, 'User')
  Write-Output "$destination added to the user PATH; terminals opened before need restarting."
}
# Run through iex, the script shares the user's session: bonk works there at once.
if (($env:Path -split ';') -notcontains $destination) { $env:Path = "$env:Path;$destination" }
bonk --version
