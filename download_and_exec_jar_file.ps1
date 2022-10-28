<#
1. The script has to download a zip/tar file from a webserver (remotely)
2. Once its donloaded in c:\tmp or d:\temp it has extact
3. In that zip file will be a .jar file and a portable java
4. It should run the java / jar file using the portable verison of java
5. The script shld not execute if the disk space is more than 75% used
6. As this script will download from a webserver it will use creds
7. before executing the script the script should set the execution policy as well
8. The script will execute on *SYSTEMACCOUNT*

#>

Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine

Write-Host -f Green "=====//START SCRIPT//====="

#====================================//Define variable//==================="
#change the value of 2 variables '$filename' and '$link'below:
$filename = "main.zip"

$link = "https://github.com/DavidFerreira21/Office-365-Licensing-Tool/archive/refs/head/"

$fullpath = $link + $filename


function downloadPackage {

    (
        [Parameter(Mandatory=$true)] [string] $dest
    )
    $destination_path = $dest + $filename

    Write-Host "=====//Check Destination file ...."
    if (-not (Test-Path -LiteralPath $destination_path)) {
    
        Write-host -f Green  "`nProcess download to $destination_path .....`n"
    }
    else {
         Write-host -f Yellow  "`n'$destination_path' file already existed!`n"
         Write-host -f Green  "`nProcess delete and download .....`n"
         Remove-Item $destination_path
         
    }
    try {

        #below code to pass SSL

        add-type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(
        ServicePoint srvPoint, X509Certificate certificate,
        WebRequest request, int certificateProblem) {
        return true;
    }
}
"@
        [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

        #Invoke-WebRequest -Uri $fullpath -OutFile $destination_path 

        #----->>>Change Credential<<<-----
        $pass = ConvertTo-SecureString 'P@ssw0rd1' -AsPlainText -Force

        $account = "admin" 

        $cred=New-Object -TypeName PSCredential -ArgumentList @($account,$pass)
                        
        Invoke-WebRequest -Uri $fullpath -OutFile $destination_path -Credential $credential

    }
    catch {
        Write-Error -Message "Unable to DOWNLOAD. Error was: $_" -ErrorAction stop
        break
    }
}

function extractPackage {
    
    (
        [Parameter(Mandatory=$true)] [string] $dest
    )
    $destination_path = $dest + $filename

    Write-host -f Green  "=====//Process extract '$destination_path'...`n"
    Expand-Archive -LiteralPath $destination_path -DestinationPath $dest

}

#Create function run a '.jar' file using 'java portable'!
#Need to correct the name of java_portable_name
function JAVA_run {
    
    (
        [Parameter(Mandatory=$true)] [string] $dest
    )   

    #Change the name of portable java
    $java_portable_name = "jPortable_8_Update_341_online.paf"

    $java_portable_path = $dest + $filename.Split(".")[0] + +"\"+ $java_portable_name
    
    Write-host -f Green  "=====//Process running by java portable`n"
    
    #Process start java portable to run file'. jar'
    $arguments = "start java_portable_path -jar $destination_path"
    
    Start-Process powershell -ArgumentList $arguments
}

#Create function to check 'C:\tmp' or 'D:\tmp' already existed or not
function create_tmp_folder {

    (
        [Parameter(Mandatory=$true)] [string] $dest 
    )  

    if (-not (Test-Path -LiteralPath $dest)) {
    
        try {
             New-Item -Path $dest -ItemType Directory -ErrorAction Stop | Out-Null #-Force
             Start-Sleep 5
             Write-output "Successfully created $dest"
        }
        catch {
             Write-Error -Message "Unable to create directory '$dest'. Error was: $_" -ErrorAction Stop
         
        }
    
    }
    else {
        Write-output "Directory $dest exists!"
    }
}
 
 #====================================//Scan all Disks//==================="
 $DiskObjects = Get-WmiObject win32_logicaldisk -Filter "Drivetype=3"

 foreach ($disk in $DiskObjects)
 {
    $Name           = $disk.DeviceID
    $Capacity       = [math]::Round($disk.Size / 1073741824, 2)
    $FreeSpace      = [math]::Round($disk.FreeSpace / 1073741824, 2)
    $FreePercentage = [math]::Round($disk.FreeSpace / $disk.size * 100, 1)
    
    if ($Name -eq "C:") {

        
        Write-Host "Name: $Name"
        Write-Host "Capacity (GB): $Capacity"
        Write-Host "FreeSpace (GB): $FreeSpace"
        Write-Host "FreePercentage (%): $FreePercentage"

        #Check disk space greater 25% 
        if ($FreePercentage -gt 25) {
            Write-Host -f Green "==> Disk C:\ is normal"
            
            #Create C:\tmp\ if it did not exist
            create_tmp_folder -dest "C:\tmp\"
            
            #Call function download package
            downloadPackage -dest "C:\tmp\"

            #Call function Extract package
            extractPackage -dest "C:\tmp\"

            #Call function Java run file
            JAVA_run -dest "C:\tmp\"

            break #Out this loop
        }
        else {
            Write-Host -f Yellow "==> Disk C:\ is not enough space"
        }
    }
    else {
        if ($Name -eq "D:") {
  
            Write-Host "Name: $Name"
            Write-Host "Capacity (GB): $Capacity"
            Write-Host "FreeSpace (GB): $FreeSpace"
            Write-Host "FreePercentage (%): $FreePercentage"
            
            #Check disk space greater 25% 
            if ($FreePercentage -gt 25) {
                Write-Host -f Green "==> Disk D:\ is normal"

                #Create D:\tmp\ if it did not exist
                create_tmp_folder -dest "D:\tmp\"

                #Call function download package
                downloadPackage -dest "D:\tmp\"

                #Call function Extract package
                extractPackage -dest "D:\tmp\"

                #Call function Java run file
                JAVA_run -dest "D:\tmp\"

                break #Out this loop
            }
            else {
                Write-Host -f Yellow "==> Disk D:\ is not enough space"
            }
        }

    }
 }
 
 Write-Host -f Green "=====//DONE SCRIPT//====="