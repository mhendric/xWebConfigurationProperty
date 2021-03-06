function Get-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$Filter,

		[parameter(Mandatory = $true)]
		[System.String]
		$Name,

		[parameter(Mandatory = $true)]
		[ValidateSet("Boolean","Int64","String")]
		[System.String]
		$ValueType,

		[System.String]
		$ValueBool,

		[System.String]
		$ValueString,

		[System.Int64]
		$ValueInt,

		[System.Boolean]
		$Force,

		[System.String]
		$Location,

		[parameter(Mandatory = $true)]
		[System.String]
		$PSPath,

		[System.Boolean]
		$AllowServiceRestart = $false
	)

    LogFunctionEntry -Parameters @{"Filter" = $Filter;"PSPath" = $PSPath;"Name" = $Name} -VerbosePreference $VerbosePreference

    #Create a copy of the original parameters
    $originalPSBoundParameters = @{} + $PSBoundParameters

	RemoveParameters -PSBoundParametersIn $PSBoundParameters -ParamsToKeep 'Filter','Name','PSPath'

    $configProp = Get-WebConfigurationProperty @PSBoundParameters -ErrorAction SilentlyContinue

    #Add original props back
    AddParameters -PSBoundParametersIn $PSBoundParameters -ParamsToAdd $originalPSBoundParameters

	if ($configProp -ne $null)
    {
	    $returnValue = @{
		    Filter = $Filter
		    Name = $Name
            PSPath = $PSPath
		    ValueType = $ValueType		    
	    }

        switch ($ValueType)
        {
            Boolean {$returnValue.Add("ValueBool", $configProp.Value)}
            Int64 {$returnValue.Add("ValueInt", $configProp.Value)}
            String {$returnValue.Add("ValueString", $configProp.Value)}
            Default { Write-Error "Encountered unexpected ValueType of '$($ValueType)'"}
        }
    }

	$returnValue
}


function Set-TargetResource
{
	[CmdletBinding()]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$Filter,

		[parameter(Mandatory = $true)]
		[System.String]
		$Name,

		[parameter(Mandatory = $true)]
		[ValidateSet("Boolean","Int64","String")]
		[System.String]
		$ValueType,

		[System.String]
		$ValueBool,

		[System.String]
		$ValueString,

		[System.Int64]
		$ValueInt,

		[System.Boolean]
		$Force,

		[System.String]
		$Location,

		[parameter(Mandatory = $true)]
		[System.String]
		$PSPath,

		[System.Boolean]
		$AllowServiceRestart = $false
	)

    LogFunctionEntry -Parameters @{"Filter" = $Filter;"PSPath" = $PSPath;"Name" = $Name} -VerbosePreference $VerbosePreference

    switch ($ValueType)
    {
        Boolean {$Value = $ValueBool}
        Int64 {$Value = $ValueInt}
        String {$Value = $ValueString}
        Default { Write-Error "Encountered unexpected ValueType of '$($ValueType)'"}
    }

    RemoveParameters -PSBoundParametersIn $PSBoundParameters -ParamsToRemove 'ValueType','ValueBool','ValueString','ValueInt','AllowServiceRestart'
    AddParameters -PSBoundParametersIn $PSBoundParameters -ParamsToAdd @{"Value" = $Value}

    Set-WebConfigurationProperty @PSBoundParameters

    if($AllowServiceRestart -eq $true)
    {
        Write-Verbose "Restarting IIS"

        Invoke-Expression -Command "iisreset /noforce /timeout:300"
    }
    else
    {
        Write-Warning "The configuration will not take effect until 'IISReset /noforce' is run."
    }
}


function Test-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Boolean])]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$Filter,

		[parameter(Mandatory = $true)]
		[System.String]
		$Name,

		[parameter(Mandatory = $true)]
		[ValidateSet("Boolean","Int64","String")]
		[System.String]
		$ValueType,

		[System.String]
		$ValueBool,

		[System.String]
		$ValueString,

		[System.Int64]
		$ValueInt,

		[System.Boolean]
		$Force,

		[System.String]
		$Location,

		[parameter(Mandatory = $true)]
		[System.String]
		$PSPath,

		[System.Boolean]
		$AllowServiceRestart = $false
	)

    LogFunctionEntry -Parameters @{"Filter" = $Filter;"PSPath" = $PSPath;"Name" = $Name} -VerbosePreference $VerbosePreference

    #Create a copy of the original parameters
    $originalPSBoundParameters = @{} + $PSBoundParameters

	RemoveParameters -PSBoundParametersIn $PSBoundParameters -ParamsToKeep 'Filter','Name','PSPath'

    $configProp = Get-WebConfigurationProperty @PSBoundParameters -ErrorAction SilentlyContinue

    #Add original props back
    AddParameters -PSBoundParametersIn $PSBoundParameters -ParamsToAdd $originalPSBoundParameters

    if ($configProp -ne $null)
    {
        switch ($ValueType)
        {
            Boolean
            {
                if (!(VerifySetting -Name "ValueBool" -Type "Boolean" -ExpectedValue $ValueBool -ActualValue $configProp.Value -PSBoundParametersIn $PSBoundParameters -VerbosePreference $VerbosePreference))
                {
                    return $false
                }
            }
            Int64
            {
                if (!(VerifySetting -Name "ValueInt" -Type "Int" -ExpectedValue $ValueInt -ActualValue $configProp.Value -PSBoundParametersIn $PSBoundParameters -VerbosePreference $VerbosePreference))
                {
                    return $false
                }
            }
            String
            {
                if (!(VerifySetting -Name "ValueString" -Type "String" -ExpectedValue $ValueString -ActualValue $configProp.Value -PSBoundParametersIn $PSBoundParameters -VerbosePreference $VerbosePreference))
                {
                    return $false
                }
            }
            Default {return $false}        
        }
    }
    else
    {
        return $false
    }

    return $true
}

#Takes $PSBoundParameters from another function and adds in the keys and values from the given Hashtable
function AddParameters
{
    param($PSBoundParametersIn, [Hashtable]$ParamsToAdd)

    foreach ($key in $ParamsToAdd.Keys)
    {
        if (!($PSBoundParametersIn.ContainsKey($key))) #Key doesn't exist, so add it with value
        {
            $PSBoundParametersIn.Add($key, $ParamsToAdd[$key]) | Out-Null
        }
        else #Key already exists, so just replace the value
        {
            $PSBoundParametersIn[$key] = $ParamsToAdd[$key]
        }
    }
}

#Takes $PSBoundParameters from another function. If ParamsToRemove is specified, it will remove each param.
#If ParamsToKeep is specified, everything but those params will be removed. If both ParamsToRemove and ParamsToKeep
#are specified, only ParamsToKeep will be used.
function RemoveParameters
{
    param($PSBoundParametersIn, [string[]]$ParamsToKeep, [string[]]$ParamsToRemove)

    if ($ParamsToKeep -ne $null -and $ParamsToKeep.Count -gt 0)
    {
        [string[]]$ParamsToRemove = @()

        $lowerParamsToKeep = StringArrayToLower -Array $ParamsToKeep

        foreach ($key in $PSBoundParametersIn.Keys)
        {
            if (!($lowerParamsToKeep.Contains($key.ToLower())))
            {
                $ParamsToRemove += $key
            }
        }
    }

    if ($ParamsToRemove -ne $null -and $ParamsToRemove.Count -gt 0)
    {
        foreach ($param in $ParamsToRemove)
        {
            $PSBoundParametersIn.Remove($param) | Out-Null
        }
    }
}

#Takes an array of strings and converts all elements to lowercase
function StringArrayToLower
{
    param([string[]]$Array)
    
    if ($Array -ne $null)
    {
        for ($i = 0; $i -lt $Array.Count; $i++)
        {
            if (!([string]::IsNullOrEmpty($Array[$i])))
            {
                $Array[$i] = $Array[$i].ToLower()
            }
        }
    }

    return $Array
}

function VerifySetting
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param([string]$Name, [string]$Type, $ExpectedValue, $ActualValue, $PSBoundParametersIn, $VerbosePreference)

    $returnValue = $true

    if ($PSBoundParametersIn.ContainsKey($Name))
    {
        if ($Type -like "String")
        {
            if ((CompareStrings -String1 $ExpectedValue -String2 $ActualValue -IgnoreCase) -eq $false)
            {
                $returnValue = $false
            }
        }
        elseif ($Type -like "Boolean")
        {
            if ((CompareBools -Bool1 $ExpectedValue -Bool2 $ActualValue) -eq $false)
            {
                $returnValue = $false
            }
        }
        elseif ($Type -like "Int")
        {
            if ($ExpectedValue -ne $ActualValue)
            {
                $returnValue = $false
            }
        }
        else
        {
            throw "Type not found: $($Type)"
        }
    }

    if ($returnValue -eq $false)
    {
        ReportBadSetting -SettingName $Name -ExpectedValue $ExpectedValue -ActualValue $ActualValue -VerbosePreference $VerbosePreference
    }

    return $returnValue
}

function ReportBadSetting
{
    param($SettingName, $ExpectedValue, $ActualValue, $VerbosePreference)

    Write-Verbose "Invalid setting '$($SettingName)'. Expected value: '$($ExpectedValue)'. Actual value: '$($ActualValue)'"
}

#Checks if two strings are equal, or are both either null or empty
function CompareStrings
{
    param([string]$String1, [string]$String2, [switch]$IgnoreCase)

    if (([string]::IsNullOrEmpty($String1) -and [string]::IsNullOrEmpty($String2)))
    {
        return $true
    }
    else
    {
        if ($IgnoreCase -eq $true)
        {
            return ($String1 -like $String2)
        }
        else
        {
            return ($String1 -clike $String2)
        }
    }
}

#Checks if two bools are equal, or are both either null or false
function CompareBools($Bool1, $Bool2)
{
    if($Bool1 -ne $Bool2)
    {
        if (!(($Bool1 -eq $null -and $Bool2 -eq $false) -or ($Bool2 -eq $null -and $Bool1 -eq $false)))
        {
            return $false
        }
    }

    return $true
}

function LogFunctionEntry
{
    param([Hashtable]$Parameters, $VerbosePreference)

    $callingFunction = (Get-PSCallStack)[1].FunctionName

    if ($Parameters -ne $null -and $Parameters.Count -gt 0)
    {
        $parametersString = ""

        foreach ($key in $Parameters.Keys)
        {
            $value = $Parameters[$key]

            if ($parametersString -ne "")
            {
                $parametersString += ", "
            }

            $parametersString += "$($key) = '$($value)'"
        }    

        Write-Verbose "Entering function '$($callingFunction)'. Notable parameters: $($parametersString)"
    }
    else
    {
        Write-Verbose "Entering function '$($callingFunction)'."
    }
}

Export-ModuleMember -Function *-TargetResource

