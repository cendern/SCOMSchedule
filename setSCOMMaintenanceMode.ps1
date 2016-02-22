<# 
.SYNOPSIS 
    Sets a list of SCOM entities into maintenance mode
.DESCRIPTION 
	Sets a list of SCOM entities into maintenance mode starting now
    and persisting for 'duration' minutes with the comment text
    specified in 'comment'
.NOTES 
	Author     : Charlie Noble
.EXAMPLE 
    Specify Display Names on the command line:
	<scriptName> -listOfDisplayNames "http://uprtpwb6.csus.edu [On Campus Web Test]","http://my.csus.edu [On Campus Web Test]" -comment "Just node 6 and the http web test" -durationInMinutes 5
    Output     :

.EXAMPLE 
    Get Display Names from a file:
    <scriptName> -listOfDisplayNames $(Get-Content "C:\SCOM\entityLists\maintmode_entities.txt") -comment "Just node 6 and the http web test" -durationInMinutes 5
.PARAMETER listOfDisplayNames
    An array of displayName values that correspond to values in the Display Name column in the graphical SCOM console.
.PARAMETER comment
    Text to add to the Comment field visible under the 'maintenance mode'->'edit maintenance mode settings' context
.PARAMETER durationInMinutes
    How long to set maintenance mode (in minutes)
.PARAMETER SCOMServerName
    The name of the SCOM server
.PARAMETER propFile
    Path to a properties file containing settings that have a lower priority than those specified on the command line
#> 
#@Author Charlie Noble
#@Date 2016-02-19
#@Description Set a list of SCOM entities into maintenance mode starting now, for a specified duration.

#No code can go above here
#Give up on using their parameter requirements, do it manually
#[CmdletBinding(DefaultParameterSetName="noprofileA")]
param(
    #[parameter(Mandatory=$false,ParameterSetName="withpropfile")]
    #[parameter(Mandatory=$true,ParameterSetName="nopropfileA")]
    [parameter(HelpMessage="A comma-delimited list of quoted `"Display Name`" strings (the Display Name of each of the SCOM entities to set to maintenance mode)")]
    [alias('l')]
    #[String[]]$listOfDisplayNames=$(throw "Please specify at least one Display Name to set to maintenance mode" ),
    [String[]]$listOfDisplayNames,

    #[parameter(Mandatory=$false,ParameterSetName="withpropfile")]
    #[parameter(Mandatory=$true,ParameterSetName="nopropfileB")]
    [parameter(HelpMessage="The text that appears in the 'Comment' field in maintenance mode properties")]
    [alias('c')]
    #[String]$comment=$(throw "Please specify a comment" ),
    [String]$comment,

    [parameter(HelpMessage="The duration to set for maintenance mode in minutes")]
    [alias('d')]
        [int]$durationInMinutes,

    [parameter(HelpMessage="The SCOM server name")]
    [String]$SCOMServerName,

    #[parameter(Mandatory=$true,ParameterSetName="withpropfile")]
    #[parameter(Mandatory=$false,ParameterSetName="nopropfileA")]
    #[parameter(Mandatory=$false,ParameterSetName="nopropfileB")]
    [parameter(HelpMessage="A file containing some or all settings. Command line settings override these")]
    [String]$propFile
)
#Specify defaults here
$defaultableParams=@{"durationInMinutes"=60;"SCOMServerName"="irt-om01.saclink.csus.edu"};

#Params inherited by default; use as an exclusion list
$inheritedParams=@(
    "Verbose",
    "Debug",
    "ErrorAction",
    "WarningAction",
    "ErrorVariable",
    "WarningVariable",
    "OutVariable",
    "OutBuffer",
    "PipelineVariable"
 );


#Read the properties file specified in the propFile parameter.
if ( ! [String]::isNullOrEmpty($propFile)) {
    if (Test-Path $propFile) {
        $AppProps = convertfrom-stringdata (get-content $propFile -raw);
    } else {
        $AppProps = @{};
    }
} else {
    $AppProps = @{};
}

#Iterate through the list of populated parameters, ignoring 'propFile' and those
# provided by default.
# Populate the rest using command-line inputs, propFile values, and 
# hardcoded defaults, in that order of preference.
#It seems like I should be able to accomplish at least some of this 
# in the param() block, but I couldn't figure out how.

#$PSBoundParameters is a writeable hash table of parameters that 
# have values assigned to them
#Looking up the parameters list allows easier development because we
# can add another parameter without touching this block.

#Iterate over the list of all of this cmdlet's parameters:
foreach ($k in $($myInvocation.MyCommand).Parameters.Keys.GetEnumerator()){
    #$k is a string equal to a param name
    #Look for a value for $k in PSBoundParameters
    #Can .Add() to PSBoundParameters! Yay!
    if (! $inheritedParams.Contains($k)){
        if (! $PSBoundParameters.ContainsKey($k)) {
            #Not set on command line, see if we have it in propFile
            if ($AppProps.ContainsKey($k)){
                $PSBoundParameters.Add($k,$AppProps[$k]); 
            } else {
                #Not set anywhere. Can we default this one?
                if ($defaultableParams.ContainsKey($k)){
                    $PSBoundParameters.Add($k,$defaultableParams[$k]); 
                } else {
                    if ($k -ne "propFile"){
                        Throw "Couldn't find a suitable value for $k";
                    }
                }
            }
        } ;# else already set on command line/in PSBoundParameters
    }#else if it's an inherited param, we don't need to specify it
}

#$PSBoundParameters



#foreach ($e in $listOfDisplayNames) {write-host "`Applying to entity $e";}
#write-host "`$comment is $comment";
#write-host "`$durationInMinutes is $durationInMinutes";
#write-host "`$SCOMServerName is $SCOMServerName";
#exit
#May need this,  may not:
#Import-Module OperationsManager

#Connect to the SCOM server
#We don't do anything with $connect, but if we don't assign it to a var, its value will print to the screen
$connect = New-SCOMManagementGroupConnection –ComputerName $SCOMServerName

#Just maintenance mode for now
#$agentWatcherClass = get-SCOMclass -name:Microsoft.SystemCenter.AgentWatcher
#$healthServiceWatcherClass = get-SCOMclass -name:Microsoft.SystemCenter.HealthServiceWatcher
 
$StartTime = ([DateTime]::Now).ToUniversalTime()
$EndTime = $StartTime.AddMinutes($durationInMinutes)
$Reason = "PlannedOther"
$fullComment = "$comment`r`n`r`nStart time: $($StartTime.ToLocalTime())`r`nEnd   Time: $($EndTime.ToLocalTime())"

write-host "Setting maintenance mode with comment:";
write-host "================================";
write-host "$fullComment";
write-host "================================";
write-host "";
write-host "for the following entities:";

#Make an empty array so we can append our SCOM entities
#Cast to ArrayList or we won't be able to add to it
[System.Collections.ArrayList]$entityList=@();

ForEach ($dName in $listOfDisplayNames) {

    #Use the displayname to get the SCOM entity
    $entity=Get-SCOMClassInstance |where-object {$_.DisplayName -eq $dName};

    #Static string method here:
    if ([String]::IsNullOrEmpty($entity)) {
        write-host "Couldn't find a SCOM entity with Display Name `"$dName`"";
    } else {
        #Set maintenance mode
        $entity.ScheduleMaintenanceMode($StartTime, $EndTime, $Reason, $fullComment)
        $ignoreReturnValue=$entityList.Add($entity);

        #Just maintenance mode for now
        #$agentwatcher =         get-scommonitoringobject -class $agentWatcherClass         | Where-Object {$_ -eq $entity}
        #$agentwatcher.ScheduleMaintenanceMode($StartTime, $EndTime, $Reason, $fullComment)
        #$healthServiceWatcher = get-scommonitoringobject -class $healthServiceWatcherClass | Where-Object {$_ -eq $entity}
        #$healthServiceWatcher.ScheduleMaintenanceMode($StartTime, $EndTime, $Reason, $fullComment)
    }
}

#Doing it this way prints the entities and their status, though there's probably a way to do
# this without the ForEach
ForEach ($entity in $entityList) {
    write-host "$entity"
    write-host "  In maintenance mode: $($entity.InMaintenanceMode)";
    write-host "  Start: $($entity.GetMaintenanceWindow().StartTime)";
    write-host "  End  : $($entity.GetMaintenanceWindow().scheduledEndTime)";
    write-host "";
}