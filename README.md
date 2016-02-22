# SCOMSchedule
Scripted interface to scheduling SCOM maintenance mode

Initiate maintenance mode in SCOM with:
%SystemRoot%\system32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy ByPass -File <repoPath>\SCOMSchedule\setSCOMMaintenanceMode.ps1 -propFile c:\path\to\stuff.properties
or
%SystemRoot%\system32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy ByPass -File <repoPath>\SCOMSchedule\setSCOMMaintenanceMode.ps1 -listOfDisplayNames "server 1 display name","server 2 display name" -comment "Maintenance for servers 1 and 2"

To do:
Add functionality to schedule a task that will run the script above.