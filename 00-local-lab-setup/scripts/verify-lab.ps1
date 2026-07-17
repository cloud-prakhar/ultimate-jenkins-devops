$urls = @(
  @{ Name = "Jenkins"; Uri = "http://127.0.0.1:8080/login" },
  @{ Name = "Gitea"; Uri = "http://127.0.0.1:3000/" },
  @{ Name = "Registry"; Uri = "http://127.0.0.1:5000/v2/" }
)

foreach ($item in $urls) {
  try {
    Invoke-WebRequest -UseBasicParsing -Uri $item.Uri | Out-Null
    Write-Host "[pass] $($item.Name) reachable"
  }
  catch {
    throw "$($item.Name) is not reachable at $($item.Uri)"
  }
}
