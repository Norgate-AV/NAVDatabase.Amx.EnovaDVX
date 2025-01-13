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

function Get-ConfigConverter {
    param (
        [string]$Path,
        [switch]$To
    )

    switch ([System.IO.Path]::GetExtension($Path)) {
        ".json" {
            if ($To) {
                { process { $_ | ConvertTo-Json -Depth 10 } }
            }
            else {
                { process { $_ | ConvertFrom-Json } }
            }
        }
        { $_ -in ".yaml", ".yml" } {
            if ($To) {
                { process { $_ | ConvertTo-Yaml } }
            }
            else {
                { process { $_ | ConvertFrom-Yaml } }
            }
        }
        default { throw "Unsupported file extension: $Path" }
    }
}

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

            # Check for a matching checksum file at the same url
            # Download and verify the checksum if it exists
            $checksumUrl = "$fileUrl.sha256"
            $checksumPath = "$filePath.sha256"

            if (Invoke-WebRequest -Uri $checksumUrl -UseBasicParsing -Method Head -ErrorAction SilentlyContinue) {
                Write-Host "Verifying checksum..."
                Invoke-WebRequest -Uri $checksumUrl -OutFile $checksumPath

                $checksum = Get-Content -Path $checksumPath
                $hash = Get-FileHash -Path $filePath -Algorithm SHA256

                if ($hash.Hash -ne $checksum) {
                    throw "Checksum verification failed for $file"
                }
            }

            # Delete checksum file
            if (Test-Path $checksumPath) {
                Remove-Item -Path $checksumPath
            }

            # Extract archive
            Write-Host "Extracting $file..."
            $global:ProgressPreference = "SilentlyContinue"
            Expand-Archive -Path $filePath -DestinationPath $destinationPath
            $global:ProgressPreference = "Continue"

            # Delete archive
            Remove-Item -Path $filePath
        }
    }
    catch {
        throw "Failed to download release: $_"
    }
}

function Find-GenlinxRc {
    param (
        [string]$Path
    )

    $genlinxrcPath = Get-ChildItem -Path $Path -Recurse -File -Filter ".genlinxrc.*" `
        -ErrorAction SilentlyContinue | Select-Object -First 1

    return $genlinxrcPath
}

function Update-GenlinxRc {
    param (
        [string]$Path,
        [string]$OutDir,
        [string]$DependencyUrl,
        [string]$DependencyVersion
    )

    if (-not (Test-Path $Path)) {
        throw "Invalid path: $Path"
    }

    Write-Host "Updating .genlinxrc..."

    $convertFrom = Get-ConfigConverter -Path $Path
    $convertTo = Get-ConfigConverter -Path $Path -To

    $genlinxrc = Get-Content -Path $Path -Raw | & $convertFrom

    $genlinxrc.build.nlrc.includePath += "./$OutDir/$DependencyUrl/$DependencyVersion"
    $genlinxrc.build.nlrc.modulePath += "./$OutDir/$DependencyUrl/$DependencyVersion"

    # Ensure the paths are unique
    $genlinxrc.build.nlrc.includePath = @($genlinxrc.build.nlrc.includePath | Select-Object -Unique)
    $genlinxrc.build.nlrc.modulePath = @($genlinxrc.build.nlrc.modulePath | Select-Object -Unique)

    $genlinxrc | & $convertTo | Out-File -FilePath $Path -NoNewline
}

function New-GenlinxRc {
    param (
        [string]$Path
    )

    $contents = @{
        build = @{
            nlrc = @{
                includePath = @()
                modulePath = @()
            }
        }
    }

    $contents | ConvertTo-Json -Depth 10 | Out-File -FilePath "$Path/.genlinxrc.json"
}

function Get-Version {
    param (
        [string]$Version
    )

    if ($Version -notmatch "^\d+\.\d+\.\d+$") {
        throw "Invalid version format: $Version"
    }

    # If the version starts with ^, this means "this version or higher"
    # In this case, we need to find out if there is a newer release that we can use
    # If there is, we should use that version instead


    # If the version starts with ~, this means "this version or higher, but not the next major version"
    # If it doesn't start with ^ or ~, it's an exact version

    $version = $Version -replace "^v", ""
    return $version
}

try {
    $Path = Resolve-Path -Path $Path

    $manifest = Get-Content -Path "$Path/manifest.json" -Raw | ConvertFrom-Json

    if (!$manifest) {
        Write-Error "No manifest.json file found in $Path"
        exit 1
    }

    $vendorPath = Join-Path $PSScriptRoot $OutDir

    $genlinxrc = Find-GenlinxRc -Path $Path
    if (!$genlinxrc) {
        Write-Host
        Write-Host "Creating new .genlinxrc file..."
        New-GenlinxRc -Path $Path

        $genlinxrc = Find-GenlinxRc -Path $Path
    }

    if ($genlinxrc.Extension -match "yml|yaml") {
        if (-not (Get-Module -Name powershell-yaml -ListAvailable)) {
            Write-Host "Installing powershell-yaml module..."
            Install-Module -Name powershell-yaml -Scope CurrentUser -Force
        }

        Import-Module -Name powershell-yaml
    }

    foreach ($dependency in $manifest.dependencies) {
        Write-Host
        Write-Host "Processing dependency from $($dependency.url)..."

        try {
            # Parse the version string
            # It should be valid semver
            # If the version starts with ^, this means "this version or higher"
            # If the version starts with ~, this means "this version or higher, but not the next major version"
            # If it doesn't start with ^ or ~, it's an exact version
            # if ($dependency.version -notmatch "^\d+\.\d+\.\d+$") {
            #     throw "Invalid version format: $($dependency.version)"
            # }

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

            Write-Host "Successfully installed $($repoInfo.Repo)@$($dependency.version)"

            if (!$genlinxrc) {
                continue
            }

            Update-Genlinxrc `
                -Path $genlinxrc `
                -OutDir $OutDir `
                -DependencyUrl $repoInfo.Repo `
                -DependencyVersion $dependency.version
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
