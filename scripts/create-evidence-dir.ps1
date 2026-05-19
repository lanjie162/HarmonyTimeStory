# Get UTC timestamp and create evidence directory
$ts = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHHmmssZ')
$dir = "document/evidence/local/$ts-hypium-evidence"
New-Item -ItemType Directory -Force -Path $dir | Out-Null
Write-Host "EVIDENCE_DIR=$dir"
Write-Host "TIMESTAMP=$ts"