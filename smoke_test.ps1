param(
    [string]$ImageName = "wine-quality-api:local",
    [string]$ContainerName = "wine-quality-api-test",
    [int]$Port = 8000,
    [string]$StudentName = "rushikesh",
    [string]$RollNumber = "2022bcs0151",
    [switch]$Pull
)

$ErrorActionPreference = 'Stop'

function Invoke-Native {
    param(
        [Parameter(Mandatory = $true)][string]$File,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [string]$ErrorMessage = "Native command failed"
    )

    $output = & $File @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        $details = ($output | Out-String).Trim()
        if (-not $details) {
            $details = "(no output)"
        }
        throw "$ErrorMessage`nCommand: $File $($Arguments -join ' ')`nOutput: $details"
    }
    return $output
}

function Get-HttpStatusCode {
    param(
        [Parameter(Mandatory = $true)][string]$Uri,
        [Parameter(Mandatory = $true)][ValidateSet('GET','POST')][string]$Method,
        [string]$Body,
        [int]$TimeoutSec = 3
    )

    try {
        $params = @{
            Uri = $Uri
            Method = $Method
            TimeoutSec = $TimeoutSec
        }

        $iwrParams = (Get-Command Invoke-WebRequest).Parameters
        if ($iwrParams.ContainsKey('UseBasicParsing')) {
            $params.UseBasicParsing = $true
        }

        if ($Method -eq 'POST') {
            $params.ContentType = 'application/json'
            $params.Body = $Body
        }

        Invoke-WebRequest @params | Out-Null
        return 200
    } catch {
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
            return [int]$_.Exception.Response.StatusCode
        }
        return 0
    }
}

$containerStarted = $false
$success = $false
$failureDetails = $null

try {
    Write-Host "Stage 1/6: Pull Docker image"
    if ($Pull) {
        Invoke-Native -File docker -Arguments @('pull', $ImageName) -ErrorMessage "docker pull failed" | Out-Host
    } else {
        Write-Host "Skipping pull (use -Pull to force)"
    }

    # Fail fast if Docker engine isn't reachable.
    Invoke-Native -File docker -Arguments @('info') -ErrorMessage "Docker engine not reachable. Start Docker Desktop / daemon and retry." | Out-Null

    Write-Host "Stage 2/6: Run container"
    try {
        & docker rm -f $ContainerName 2>$null | Out-Null
    } catch {
        # Ignore missing container errors.
    }

    # If we're not pulling, the image may need to be built locally.
    if (-not $Pull) {
        $null = & docker image inspect $ImageName 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Docker image '$ImageName' not found locally. Run: docker build -t $ImageName . (or use -Pull with a Docker Hub image)"
        }
    }

    Invoke-Native -File docker -Arguments @('run', '-d', '--name', $ContainerName, '-p', "${Port}:8000", $ImageName) -ErrorMessage "docker run failed (common causes: port already in use, image missing, docker engine not running)" | Out-Null
    $containerStarted = $true

    Write-Host "Stage 3/6: Wait for readiness (/health every 5s, timeout 30s)"
    $deadline = (Get-Date).AddSeconds(30)
    $baseUrl = "http://127.0.0.1:$Port"

    while ((Get-Date) -lt $deadline) {
        $code = Get-HttpStatusCode -Uri "$baseUrl/health" -Method GET -TimeoutSec 3
        if ($code -eq 200) {
            Write-Host "Ready (HTTP 200)"
            break
        }
        Write-Host "Not ready yet (HTTP $code). Retrying in 5s..."
        Start-Sleep -Seconds 5
    }

    $finalHealthCode = Get-HttpStatusCode -Uri "$baseUrl/health" -Method GET -TimeoutSec 3
    if ($finalHealthCode -ne 200) {
        throw "Timed out waiting for readiness (final /health HTTP $finalHealthCode)"
    }

    Write-Host "Stage 4/6: Valid predict request"
    $predictResponse = Invoke-RestMethod -Uri "$baseUrl/predict" -Method Post -ContentType 'application/json' -Body '{"alcohol":10}'
    if (-not ($predictResponse.PSObject.Properties.Name -contains 'wine_quality')) {
        throw "Response missing wine_quality"
    }

    $formatted = $predictResponse | ConvertTo-Json -Compress
    Write-Host "Name: $StudentName | Roll: $RollNumber | Output: $formatted"

    Write-Host "Stage 5/6: Invalid predict request (expect 4xx/5xx)"
    $invalidCode = Get-HttpStatusCode -Uri "$baseUrl/predict" -Method POST -Body '{"alcohol":"bad"}' -TimeoutSec 5
    Write-Host "Invalid request HTTP status: $invalidCode"
    if ($invalidCode -lt 400) {
        throw "Expected 4xx/5xx for invalid request, got $invalidCode"
    }

    Write-Host "Stage 6/6: Stop and remove container"
    docker rm -f $ContainerName 2>$null | Out-Null
    $containerStarted = $false

    $success = $true
} catch {
    $failureDetails = ($_ | Out-String).TrimEnd()
} finally {
    if ($containerStarted) {
        try {
            docker rm -f $ContainerName 2>$null | Out-Null
        } catch {
            # Ignore cleanup errors.
        }
    }

    if ($success) {
        Write-Host "SUCCESS"
        exit 0
    } else {
        if ($failureDetails) {
            Write-Host "ERROR DETAILS:"
            Write-Host $failureDetails
        }
        Write-Host "FAILURE"
        exit 1
    }
}
