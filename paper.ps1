param(
    [string]$version
)

$javaLinks = @{
    8 = "https://corretto.aws/downloads/latest/amazon-corretto-8-x64-windows-jre.zip"
    11 = "https://corretto.aws/downloads/latest/amazon-corretto-11-x64-windows-jdk.zip"
    17 = "https://corretto.aws/downloads/latest/amazon-corretto-17-x64-windows-jdk.zip"
    21 = "https://corretto.aws/downloads/latest/amazon-corretto-21-x64-windows-jdk.zip"
}


$paperApi = 'https://api.papermc.io/v2/'
$whitebeefVersionApi = 'https://whitebeef.ru/versions/'
$existing_versions = ((Invoke-WebRequest $paperApi'projects/paper').content | Out-String | ConvertFrom-Json).versions
if (!$version) {
    $version = $existing_versions[-1]
}
if(!($existing_versions -contains $version))
{
    $error_message = "Version minecraft `""+$version+"`" does not exist, perhaps you meant: "+$existing_versions[-1]
    $error_message
    exit
}
$javaCommand = $null
$installedJavaVersion = if($null -eq (Get-Command java -ErrorAction SilentlyContinue)) {$null} else {(Get-Command java | Select-Object -ExpandProperty Version).major}
$minecraftJavaJson = (Invoke-WebRequest $whitebeefVersionApi$version).content | Out-String | ConvertFrom-Json
$supportJavaVersions = $minecraftJavaJson.supportedVersions | Sort-Object -Descending
if(($null -eq $installedJavaVersion) -Or !($supportJavaVersions -contains $installedJavaVersion)) {
    $success = $False
    foreach ($javaVersion in $supportJavaVersions)
    {
        $command = Get-Command -Name java$javaVersion -ErrorAction SilentlyContinue
        if($command){

            $javaCommand = "java$javaVersion"
            $success = $True
            break
        }
    }
    if(!$success){
        if($null -eq $installedJavaVersion){
            $error_message = "Java missing: Server requires a java version "+$minecraftJavaJson.preferredVersion+", but it's not installed"
        } else {
            $error_message = "Incorrect java version: installed '"+$installedJavaVersion+"', but requires '"+$minecraftJavaJson.preferredVersion+"'"
        }
        $error_message
        $confirmation = Read-Host "Do you want to install the required version of java? (y/n)"
        if (!($confirmation -eq 'y')) {
            exit
        }
        $success = $False
        foreach ($javaVersion in $supportJavaVersions)
        {
            if($javaLinks.ContainsKey($javaVersion)){

                $link = $javaLinks[$javaVersion]
                $javaFilename = "java"+$javaVersion+".zip"
                $link

                $ProgressPreference = 'SilentlyContinue'
                Invoke-WebRequest -Uri $link -OutFile $javaFilename
                $ProgressPreference = 'Continue'

                # Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -Command "echo chleeeeeen; pause"' -Verb RunAs -WindowStyle Hidden -Wait
                $localJavaCommand = "java$javaVersion"
                $command = 'pause'
                $command = "`$global:ProgressPreference = `"SilentlyContinue`" ; Expand-Archive $((Get-Location).toString())\$javaFilename -DestinationPath `"$Env:Programfiles\Java\jdk-$javaVersion`" -Force; Remove-Item -Path $((Get-Location).toString())\$javaFilename -Force; `$global:ProgressPreference = `"Continue`";  echo Extracted;Set-Location -Path `"$Env:Programfiles\Java\jdk-$javaVersion`"; if((Get-ChildItem -Path (Get-Location).toString() -Directory -Force).Count -eq 1){`$jdkFolder = (Get-ChildItem -Path (Get-Location).toString() -Directory)[0].Name; Set-Location `$jdkFolder; Get-ChildItem -Path (Get-Location).toString() | Move-Item -Destination (Get-Item (Get-Location).toString()).Parent.FullName -Force; cd ..; Remove-Item `$jdkFolder -Force} ;Set-Location bin; if(Test-Path java.exe){ Copy-Item -Path `"java.exe`" -Destination `"$localJavaCommand.exe`" }; `$env:PATH -split `";`"; if(!(`$env:PATH -split `";`" -contains (Get-Location).Path)){`$Path = [Environment]::GetEnvironmentVariable(`"PATH`", `"Machine`") + [IO.Path]::PathSeparator + (Get-Location).Path.toString(); [Environment]::SetEnvironmentVariable( `"Path`", `$Path, `"Machine`" ); echo `"Java folder added to Path`"}"
                Start-Process powershell -Wait -Verb RunAs -ArgumentList `
      "-Command & { $($command -replace '"', '\"') } '$PSScriptRoot'"


                $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
                if(Get-Command -Name $localJavaCommand){
                    Write-Output ("Java version "+$javaVersion+" has been successfully installed and can be accessed by name: "+$localJavaCommand)
                    $javaCommand = $localJavaCommand
                    $success = $True
                    break
                } else {
                    Write-Warning "Java version" $javaVersion "hasn't been installed"
                    $env:Path
                }

            }

        }
        if(!$success){
            $error_message = "No link to install one of the supported java versions for this version of minecraft, install java '"+$minecraftJavaJson.preferredVersion+"' yourself"
            $error_message
            exit
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
$startFileText = $javaCommand+" -Xms"+$ramValue+"G -Xmx"+$ramValue+"G -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1 -Dusing.aikars.flags=https://mcflags.emc.gs -Daikars.new.flags=true -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -jar $filename"
# if($minecraftVersion -gt 114){
if($minecraftJavaJson.hasGui){
    $startFileText += " --nogui"
}
$startFileText += " & pause"
$startFileText | Out-File -encoding ascii start.bat
start start.bat
Pop-Location
