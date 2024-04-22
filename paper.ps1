param(
    [Alias('v')][string]$version,
    [Alias('p')][int]$port = 25565,
    [Alias('op')][switch]$openPort,
    [Alias('?')][switch]$help
)

if($help){
    Write-Output 'Command: iex "&{$(irm https://p.wbif.ru/paper)} [-version <version>] [-port <port>] [-op]"'
    return
}

[int]$javaLatestVersion = 23
[string]$paperApi = 'https://api.papermc.io/v2/'
[string]$whitebeefMavenUrl = 'https://mvn.wbif.ru/releases/ru/nikita51/AutoUPnPPortOpen/'

$javaLinks = @{
    8 = "https://corretto.aws/downloads/latest/amazon-corretto-8-x64-windows-jre.zip"
    11 = "https://corretto.aws/downloads/latest/amazon-corretto-11-x64-windows-jdk.zip"
    16 = "https://corretto.aws/downloads/latest/amazon-corretto-16-x64-windows-jdk.zip"
    17 = "https://corretto.aws/downloads/latest/amazon-corretto-17-x64-windows-jdk.zip"
    21 = "https://corretto.aws/downloads/latest/amazon-corretto-21-x64-windows-jdk.zip"
}



function javaRequired([string] $minecraftVersion) {
    $minorMinecraftVersion = ($minecraftVersion -split "\.")[1]
    if($null -eq ($minorMinecraftVersion -as [int])){
        $minorMinecraftVersion = [int]($minorMinecraftVersion -split "-")[0]
    } else {
        $minorMinecraftVersion = $minorMinecraftVersion -as [int]
    }
    
    if($minorMinecraftVersion -eq 0){
        $error_message = "Minecraft minor version is not found"
        Write-Host $error_message
        return $null
    }
    $patchMinecraftVersion = [int]($minecraftVersion -split "\.")[2]
    if($null -eq $patchMinecraftVersion){
        $patchMinecraftVersion = 0
    }

    if(($minorMinecraftVersion -ge 8) -and ($minorMinecraftVersion -le 12)){
        return @{
            min_version = 8
            max_version = $javaLatestVersion
        }
    }
    if(($minorMinecraftVersion -ge 13) -and (($minorMinecraftVersion -le 16) -and ($patchMinecraftVersion -le 4))){
        return @{
            min_version = 11
            max_version = 15
        }
    }
    if(((($minorMinecraftVersion -ge 16) -and ($patchMinecraftVersion -ge 5)) -and ($minorMinecraftVersion -le 17)) -or (($minorMinecraftVersion -eq 17) -and ($patchMinecraftVersion -le 0))){
        return @{
            min_version = 16
            max_version = 16
        }
    }
    if((($minorMinecraftVersion -gt 17) -or (($minorMinecraftVersion -ge 17) -and ($patchMinecraftVersion -ge 1))) -and $minorMinecraftVersion -lt 19){
        return @{
            min_version = 16
            max_version = $javaLatestVersion
        }
    }
    if($minorMinecraftVersion -ge 19){
        return @{
            min_version = 17
            max_version = $javaLatestVersion
        }
    }
    return $null
}

function hasGui([string] $minecraftVersion) {
    $minorMinecraftVersion = [int]($minecraftVersion -split "\.")[1]
    if($minorMinecraftVersion -eq 0){
        $error_message = "Minecraft minor version is not found"
        Write-Host $error_message
        return $false
    }
    $patchMinecraftVersion = [int]($minecraftVersion -split "\.")[2]
    if(($minorMinecraftVersion -ge 16) -or (($minorMinecraftVersion -eq 15) -and ($patchMinecraftVersion -ge 2))){
        return $true
    }
    return $false
}

if(($port -gt 65535) -or ($port -lt 1024)){
    $error_message = "Port must be specified in the range of 1024 to 65535"
    Write-Host $error_message
    return
}

$existing_versions = ((Invoke-WebRequest $paperApi'projects/paper').content | Out-String | ConvertFrom-Json).versions
if (!$version) {
    $version = $existing_versions[-1]
}
if(!($existing_versions -contains $version)){
    $error_message = "Version minecraft `""+$version+"`" does not exist, perhaps you meant: "+$existing_versions[-1]
    Write-Host $error_message
    return
}

# Write-Host $version

$javaCommand = $null
$installedJavaVersion = if($null -eq (Get-Command java -ErrorAction SilentlyContinue)) {$null} else {(Get-Command java | Select-Object -ExpandProperty Version).major}
# Write-Host $installedJavaVersion

$minecraftJavaRequired = javaRequired($version)
if($null -eq $minecraftJavaRequired) {
    return
}

if(($null -eq $installedJavaVersion) -or ($minecraftJavaRequired.min_version -gt $installedJavaVersion) -or ($minecraftJavaRequired.max_version -lt $installedJavaVersion)) {
    $success = $False
    for ($i=$minecraftJavaRequired.min_version; $i -le $minecraftJavaRequired.max_version; $i++) {
        $command = Get-Command -Name java$i -ErrorAction SilentlyContinue
        if($command){
            $javaCommand = "java$i"
            $success = $True
            break
        }
    }
    if(!$success){
        if($null -eq $installedJavaVersion){
            $error_message = "Java missing: Server requires a java version $($minecraftJavaRequired.min_version)-$($minecraftJavaRequired.max_version), but it's not installed"
        } else {
            $error_message = "Incorrect java version: installed $installedJavaVersion, but requires '$($minecraftJavaRequired.min_version)-$($minecraftJavaRequired.max_version)'"
        }
        Write-Host $error_message
        $success = $False
        foreach($i in ($javaLinks.Keys | Sort-Object)){
            if($i -lt $minecraftJavaRequired.min_version){
                continue
            }
            if($i -gt $minecraftJavaRequired.max_version){
                continue
            }
            $link = $javaLinks[$i]
            $confirmation = Read-Host "Do you want to install the $([string]$i) version of java? (y/n/skip)"
            if ($confirmation -eq 'skip' -and !($null -eq $installedJavaVersion)) {
                $javaCommand = "java"
                $success = $true
                break
            }
            if (!($confirmation -eq 'y')) {
                return
            }
            $javaFilename = "java"+$i+".zip"

            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $link -OutFile $javaFilename
            $ProgressPreference = 'Continue'
            
            $localJavaCommand = "java$i"
            $command = 'pause'
            $command = "`$global:ProgressPreference = `"SilentlyContinue`" ; Expand-Archive $((Get-Location).toString())\$javaFilename -DestinationPath `"$Env:Programfiles\Java\jdk-$i`" -Force; Remove-Item -Path $((Get-Location).toString())\$javaFilename -Force; `$global:ProgressPreference = `"Continue`";  echo Extracted;Set-Location -Path `"$Env:Programfiles\Java\jdk-$i`"; if((Get-ChildItem -Path (Get-Location).toString() -Directory -Force).Count -eq 1){`$jdkFolder = (Get-ChildItem -Path (Get-Location).toString() -Directory)[0].Name; Set-Location `$jdkFolder; Get-ChildItem -Path (Get-Location).toString() | Move-Item -Destination (Get-Item (Get-Location).toString()).Parent.FullName -Force; cd ..; Remove-Item `$jdkFolder -Force} ;Set-Location bin; if(Test-Path java.exe){ Copy-Item -Path `"java.exe`" -Destination `"$localJavaCommand.exe`" }; `$env:PATH -split `";`"; if(!(`$env:PATH -split `";`" -contains (Get-Location).Path)){`$Path = [Environment]::GetEnvironmentVariable(`"PATH`", `"Machine`") + [IO.Path]::PathSeparator + (Get-Location).Path.toString(); [Environment]::SetEnvironmentVariable( `"Path`", `$Path, `"Machine`" ); echo `"Java folder added to Path`"}"
            Start-Process powershell -Wait -Verb RunAs -ArgumentList `
    "-Command & { $($command -replace '"', '\"') } '$PSScriptRoot'"

            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            if(Get-Command -Name $localJavaCommand){
                Write-Output ("Java version "+$i+" has been successfully installed and can be accessed by name: "+$localJavaCommand)
                $javaCommand = $localJavaCommand
                $success = $True
                break
            } else {
                Write-Warning "Java version" $i "hasn't been installed"
                $env:Path
            }
        }
        if(!$success){
            $error_message = "No link to install one of the supported java versions for this version of minecraft, install java '"+$minecraftJavaRequired.min_version+"-"+$minecraftJavaRequired.max_version+"' yourself"
            Write-Host $error_message
            return
        }
    }
} else {
    $javaCommand = 'java'
}

$build = ((Invoke-WebRequest $paperApi'projects/paper/versions/'$version).content | Out-String | ConvertFrom-Json).builds[-1]
$downloadLink = $paperApi+'projects/paper/versions/'+$version+'/builds/'+$build+'/downloads/paper-'+$version+'-'+$build+'.jar'
$filename = 'paper-'+$version+'.jar'
$downloadMessage = "Download file from "+$downloadLink
Write-Output $downloadMessage

$serverPath = (Get-Location).toString()+'\'+$version
New-Item -ItemType Directory -Force -Path $serverPath | Out-Null
Push-Location $version
$ProgressPreference = 'SilentlyContinue'
Invoke-WebRequest -Uri $downloadLink -OutFile $filename
$ProgressPreference = 'Continue'

"eula=true" | Out-File -encoding ascii eula.txt

$minecraftVersion = [int](($version.Split('.') | Select-Object -SkipLast 1) -join "")
$ramValue = ([Math]::Min([Math]::Max([Math]::Floor((Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property capacity -Sum).sum /1gb /2),2),8)).toString()
$startFileText = "$javaCommand -Xms$($ramValue)G -Xmx$($ramValue)G -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1 -Dusing.aikars.flags=https://mcflags.emc.gs -Daikars.new.flags=true -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -jar $filename"
if(hasGui($version)){
    $startFileText += " --nogui"
}
$startFileText += " & pause"
$startFileText | Out-File -encoding ascii start.bat
if($port -ne 25565){
    $serverPortSetting = "server-port="+$port
    $serverPortSetting | Out-File -encoding ascii server.properties
}
if($openPort){
    $pluginPath = (Get-Location).toString()+'\plugins'
    New-Item -ItemType Directory -Force -Path $pluginPath | Out-Null
    Push-Location 'plugins'
    $url = $whitebeefMavenUrl+"maven-metadata.xml"
    $data = [xml](Invoke-WebRequest $url).content
    $pluginName = $data.metadata.artifactId
    $pluginVersion = $data.metadata.versioning.latest
    $pluginUrl = $whitebeefMavenUrl+$pluginVersion+'/'+$pluginName+'-'+$pluginVersion+'.jar'
    Invoke-WebRequest -Uri $pluginUrl -OutFile PortOpener.jar
    Pop-Location
}
Start-Process start.bat
Pop-Location
