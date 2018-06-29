#$CurrentSiteID = "C:\Users\paul.vazquez\Documents\Logs\CurrentSiteID.txt"
$Logs = "C:\Users\paul.vazquez\Documents\Logs\Logs.txt"
$PassPath = "C:\Users\paul.vazquez\Desktop\PassPath.txt"
$Sites = Import-Csv "C:\Users\paul.vazquez\Documents\QueueTest.csv"
$currentUser = "Paul Vazquez"
function Write-Log {
    param([string] $value)
    $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    Add-Content -Path $Logs -Value "$Stamp $value"
}
function Migrate-Site {
    param([string] $src = "",
    [string] $dst = "")
    Write-Log "Starting Migration attempt of $src"
    Import-Module Sharegate	
    $UserName = "paul.vazquez@navico.com"
    $Password = Get-Content $PassPath
    $Password = ConvertTo-SecureString $Password
    $copysettings = New-CopySettings -OnContentItemExists IncrementalUpdate 
    Write-Log "Copysettings set to IncrementalUpdate"
    $srcSite = Connect-Site -Url $src -UserName $UserName -Password $Password
    $dstSite = Connect-Site -Url $dst -UserName $UserName -Password $Password
    Write-Log "Source: $srcSite Destination: $dstSite"
    $result = Copy-Site -Site $srcSite -DestinationSite $dstSite -ForceNewListExperience -Subsites -CopySettings $copysettings
    Write-Log $result.Result
    Copy-ObjectPermissions -Source $srcSite -Destination $dstSite
    Write-Log "End of migration"
}
#$test = Get-Content $CurrentSiteID -Tail 1
#$test = [System.Decimal]::Parse($test)
Add-Content -Path $Logs -Value "-----------------------------------"
foreach ($line in $Sites){
    if(($line.("Status") -ne "MIGRATED") -and ($line.("Status") -ne "SKIP") ){
        $ID = $line.("ID")
        if($line.("AssignedTo") -eq $currentUser ){
            $Title = $line.("Title")
            Write-Log "ID:$ID  $Title"
            Migrate-Site -src $line.("SourceSite") -dst $line.("NewParentSite")
            $line.Status = "MIGRATED"
        }
        else{
            Write-Log "El sitio con ID: $ID no esta asignado a $currentUser"
        }
        #$test++
        #Set-Content -Path $CurrentSiteID -Value $test
        #Write-Log -value "El ID del sigiente sitio a migrar es $test"
    }
}
$Sites | Export-Csv -Path 'C:\Users\paul.vazquez\Documents\UCSVTestFile-temp.csv' -NoTypeInformation 
Remove-Item -Path 'C:\Users\paul.vazquez\Documents\QueueTest.csv'
Rename-Item -Path 'C:\Users\paul.vazquez\Documents\UCSVTestFile-temp.csv' -NewName 'QueueTest.csv'

