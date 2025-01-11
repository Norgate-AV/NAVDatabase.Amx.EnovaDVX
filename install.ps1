#!/usr/bin/env pwsh

<#
 _   _                       _          ___     __
| \ | | ___  _ __ __ _  __ _| |_ ___   / \ \   / /
|  \| |/ _ \| '__/ _` |/ _` | __/ _ \ / _ \ \ / /
| |\  | (_) | | | (_| | (_| | ||  __// ___ \ V /
|_| \_|\___/|_|  \__, |\__,_|\__\___/_/   \_\_/
                 |___/

MIT License

Copyright (c) 2023 Norgate AV Services Limited

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
#>


[CmdletBinding()]

param (
    [Parameter(Mandatory = $false)]
    [string]
    $Path = ".",

    [Parameter(Mandatory = $false)]
    [string]
    $OutDir = "vendor"
)

function Get-GitHubRepoInfo {
    param (
        [string]$url
    )

    if ($url -match "github.com/([^/]+)/([^/]+)") {
        return @{
            Owner = $matches[1]
            Repo  = $matches[2]
        }
    }

    throw "Invalid GitHub URL format: $url"
}

function Get-GitHubRelease {
    param (
        [string]$owner,
        [string]$repo,
        [string]$version,
        [string]$destinationPath
    )

    $version = $version -replace "^v", ""
    $url = "https://github.com/$owner/$repo/releases/download/v$version"

    $files = @("$repo.$version.archive.zip")

    try {
        foreach ($file in $files) {
            $fileUrl = "$url/$file"
            $filePath = Join-Path $destinationPath $file

            Write-Host "Downloading $file..."
            Invoke-WebRequest -Uri $fileUrl -OutFile $filePath
            Write-Host "Downloaded $file successfully"

            # Check for a matching checksum file at the same url
            # Download and verify the checksum if it exists
            $checksumUrl = "$fileUrl.sha256"
            $checksumPath = "$filePath.sha256"

            if (Invoke-WebRequest -Uri $checksumUrl -UseBasicParsing -Method Head -ErrorAction SilentlyContinue) {
                Write-Host "Downloading checksum..."
                Invoke-WebRequest -Uri $checksumUrl -OutFile $checksumPath
                Write-Host "Downloaded checksum successfully"

                Write-Host "Verifying checksum..."
                $checksum = Get-Content -Path $checksumPath
                $hash = Get-FileHash -Path $filePath -Algorithm SHA256

                if ($hash.Hash -ne $checksum) {
                    throw "Checksum verification failed for $file"
                }

                Write-Host "Checksum verified successfully"
            }

            # Delete checksum file
            if (Test-Path $checksumPath) {
                Remove-Item -Path $checksumPath
            }

            # Extract archive
            Write-Host "Extracting $file..."
            Expand-Archive -Path $filePath -DestinationPath $destinationPath
            Write-Host "Extracted $file successfully"

            # Delete archive
            Remove-Item -Path $filePath
        }
    }
    catch {
        throw "Failed to download release: $_"
    }
}

try {
    $Path = Resolve-Path -Path $Path

    $manifest = Get-Content -Path "$Path/manifest.json" -Raw | ConvertFrom-Json

    if (!$manifest) {
        Write-Error "No manifest.json file found in $Path"
        exit 1
    }

    $vendorPath = Join-Path $PSScriptRoot $OutDir

    foreach ($dependency in $manifest.dependencies) {
        Write-Host "`nProcessing dependency from $($dependency.url)..."

        try {
            $repoInfo = Get-GitHubRepoInfo -url $dependency.url
            $packagePath = Join-Path $vendorPath "$($repoInfo.Owner)/$($repoInfo.Repo)/$($dependency.version)"
            if (-not (Test-Path $packagePath)) {
                New-Item -ItemType Directory -Path $packagePath | Out-Null
            }
            else {
                Write-Host "Dependency $($repoInfo.Repo)@$($dependency.version) already installed"
                continue
            }

            Get-GitHubRelease `
                -owner $repoInfo.Owner `
                -repo $repoInfo.Repo `
                -version $dependency.version `
                -destinationPath $packagePath

            Write-Host "Updating .genlinxrc..."
            $genlinxrc = Get-Content -Path "$Path/.genlinxrc.json" -Raw | ConvertFrom-Json

            if ($genlinxrc.build.nlrc.includePath -notcontains "./$OutDir/$($repoInfo.Owner)/$($repoInfo.Repo)/$($dependency.version)") {
                $genlinxrc.build.nlrc.includePath += "./$OutDir/$($repoInfo.Owner)/$($repoInfo.Repo)/$($dependency.version)"
            }

            if ($genlinxrc.build.nlrc.modulePath -notcontains "./$OutDir/$($repoInfo.Owner)/$($repoInfo.Repo)/$($dependency.version)") {
                $genlinxrc.build.nlrc.modulePath += "./$OutDir/$($repoInfo.Owner)/$($repoInfo.Repo)/$($dependency.version)"
            }

            $genlinxrc | ConvertTo-Json -Depth 10 | Out-File -FilePath "$Path/.genlinxrc.json" -NoNewline
            Write-Host "Successfully installed $($repoInfo.Repo)@$($dependency.version)"
        }
        catch {
            Write-Error "Failed to process dependency $($dependency.url): $_"
            Remove-Item -Path $packagePath -Recurse -Force
            continue
        }
    }
}
catch {
    Write-Host $_.Exception.GetBaseException().Message -ForegroundColor Red
    exit 1
}
