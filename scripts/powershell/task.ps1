###############################################################################
#
# Copyright 2006 - 2026, Tomas Babej, Paul Beckingham, Federico Hernandez.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
# OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
# DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
# OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE
# USE OR OTHER DEALINGS IN THE SOFTWARE.
#
# https://www.opensource.org/licenses/mit-license.php
#
###############################################################################
#
# PowerShell tab completion for Taskwarrior.
#
# The routines will complete:
#
#    *) task subcommands and aliases (with descriptions)
#    *) attribute names and attribute values (project:, priority:, status:,
#       depends:, due:, recur:, ...)
#    *) project names, tag names (+tag / -tag), and task IDs
#    *) rc.<variable> configuration overrides, and rc:/rc.data.location: paths
#    *) context subcommands and context names
#
# To use these routines:
#
#    1) Copy this file somewhere (e.g. ~\Documents\PowerShell\task.ps1).
#    2) Add the following line to your PowerShell profile ($PROFILE):
#
#        . ~\Documents\PowerShell\task.ps1
#
# Completion data is queried through the task helpers (_commands, _columns,
# _tags, _projects, _context, _config, _zshcommands, _zshids) and briefly
# cached (see $TaskwarriorCompletionCacheTtl) so that repeated tab presses
# stay fast.
#
# To submit patches/bug reports:
#
#    *) Go to the project's website at
#
#       https://taskwarrior.org
#
###############################################################################

# The following two variables are substituted for by ../../test/powershell_completion.test.py
$TaskwarriorCompletionCommand = 'task'
$TaskwarriorCompletionRc = ''

# Seconds to cache answers from the task helpers (repeated tab presses).
$TaskwarriorCompletionCacheTtl = 5

# Cache storage, keyed by helper name.
$TaskwarriorCompletionCache = @{}

# Attribute descriptions, used as completion tooltips.
$TaskwarriorAttributeDescriptions = @{
    'description' = 'Task description text'
    'status'      = 'Status of task - pending, completed, deleted, waiting'
    'project'     = 'Project name'
    'priority'    = 'Task priority'
    'due'         = 'Due date'
    'recur'       = 'Recurrence frequency'
    'until'       = 'Expiration date'
    'limit'       = 'Desired number of rows in report'
    'wait'        = 'Date until task becomes pending'
    'entry'       = 'Date task was created'
    'end'         = 'Date task was completed/deleted'
    'start'       = 'Date task was started'
    'scheduled'   = 'Date task is scheduled to start'
    'depends'     = 'Other tasks that this task depends upon'
}

# Static value hints.
$TaskwarriorPriorityValues = @(
    @{ Value = 'L'; ToolTip = 'Low priority' }
    @{ Value = 'M'; ToolTip = 'Medium priority' }
    @{ Value = 'H'; ToolTip = 'High priority' }
)

$TaskwarriorStatusValues = @(
    @{ Value = 'pending';   ToolTip = 'Pending task' }
    @{ Value = 'completed'; ToolTip = 'Completed task' }
    @{ Value = 'deleted';   ToolTip = 'Deleted task' }
    @{ Value = 'waiting';   ToolTip = 'Waiting task' }
)

$TaskwarriorDateAttributes = @(
    'due', 'until', 'wait', 'entry', 'end', 'start', 'scheduled'
)

$TaskwarriorDateHints = @(
    @{ Value = 'today';          ToolTip = 'Today' }
    @{ Value = 'yesterday';      ToolTip = 'Yesterday' }
    @{ Value = 'tomorrow';       ToolTip = 'Tomorrow' }
    @{ Value = 'sow';            ToolTip = 'Start of week' }
    @{ Value = 'soww';           ToolTip = 'Start of work week' }
    @{ Value = 'som';            ToolTip = 'Start of month' }
    @{ Value = 'soq';            ToolTip = 'Start of quarter' }
    @{ Value = 'soy';            ToolTip = 'Start of year' }
    @{ Value = 'eow';            ToolTip = 'End of week' }
    @{ Value = 'eoww';           ToolTip = 'End of work week' }
    @{ Value = 'eom';            ToolTip = 'End of month' }
    @{ Value = 'eoq';            ToolTip = 'End of quarter' }
    @{ Value = 'eoy';            ToolTip = 'End of year' }
    @{ Value = 'mon';            ToolTip = 'Monday' }
    @{ Value = 'tue';            ToolTip = 'Tuesday' }
    @{ Value = 'wed';            ToolTip = 'Wednesday' }
    @{ Value = 'thu';            ToolTip = 'Thursday' }
    @{ Value = 'fri';            ToolTip = 'Friday' }
    @{ Value = 'sat';            ToolTip = 'Saturday' }
    @{ Value = 'sun';            ToolTip = 'Sunday' }
    @{ Value = 'goodfriday';     ToolTip = 'Good Friday' }
    @{ Value = 'easter';         ToolTip = 'Easter' }
    @{ Value = 'eastermonday';   ToolTip = 'Easter Monday' }
    @{ Value = 'ascension';      ToolTip = 'Ascension' }
    @{ Value = 'pentecost';      ToolTip = 'Pentecost' }
    @{ Value = 'midsommar';      ToolTip = 'Midsommar' }
    @{ Value = 'midsommarafton'; ToolTip = 'Midsommarafton' }
    @{ Value = 'later';          ToolTip = 'Later' }
    @{ Value = 'someday';        ToolTip = 'Some day' }
)

$TaskwarriorRecurHints = @(
    @{ Value = 'daily';      ToolTip = 'Every day' }
    @{ Value = 'day';        ToolTip = 'Every day' }
    @{ Value = 'weekdays';   ToolTip = 'Every day skipping weekend days' }
    @{ Value = 'weekly';     ToolTip = 'Every week' }
    @{ Value = 'biweekly';   ToolTip = 'Every two weeks' }
    @{ Value = 'fortnight';  ToolTip = 'Every two weeks' }
    @{ Value = 'monthly';    ToolTip = 'Every month' }
    @{ Value = 'quarterly';  ToolTip = 'Every three months' }
    @{ Value = 'semiannual'; ToolTip = 'Every six months' }
    @{ Value = 'annual';     ToolTip = 'Every year' }
    @{ Value = 'yearly';     ToolTip = 'Every year' }
    @{ Value = 'biannual';   ToolTip = 'Every two years' }
    @{ Value = 'biyearly';   ToolTip = 'Every two years' }
)

# Subcommands accepted after 'context'.
$TaskwarriorContextCommands = @('define', 'delete', 'list', 'none', 'show')

# Attribute modifiers (DEPRECATED since 2.4.0), recognized in attr.mod:value.
$TaskwarriorAttributeModifiers = @(
    'before', 'after', 'over', 'under', 'none', 'is', 'isnt', 'has', 'hasnt',
    'startswith', 'endswith', 'word', 'noword'
)

###############################################################################
# Querying taskwarrior
###############################################################################

function Get-TaskwarriorCompletionCacheEntry {
    param(
        [string]$Key,
        [scriptblock]$Factory
    )

    $now = [DateTime]::UtcNow
    if ($TaskwarriorCompletionCache.ContainsKey($Key)) {
        $entry = $TaskwarriorCompletionCache[$Key]
        if (($now - $entry.Time).TotalSeconds -le $TaskwarriorCompletionCacheTtl) {
            return $entry.Data
        }
    }

    $data = & $Factory
    $TaskwarriorCompletionCache[$Key] = @{ Time = $now; Data = $data }
    return $data
}

function Invoke-TaskwarriorCompletionHelper {
    param([string[]]$HelperArgs)

    $taskArgs = @('rc.verbose:nothing', 'rc.confirmation:no', 'rc.hooks:off')
    if ($TaskwarriorCompletionRc -ne '') {
        $taskArgs += $TaskwarriorCompletionRc
    }
    $taskArgs += $HelperArgs

    return @(& $TaskwarriorCompletionCommand @taskArgs 2>$null)
}

function Get-TaskwarriorShowMap {
    # Name -> value map of the effective configuration ("task show").
    Get-TaskwarriorCompletionCacheEntry 'show' {
        $map = @{}
        foreach ($line in (Invoke-TaskwarriorCompletionHelper @('show'))) {
            $parts = @(($line -split '\s+') | Where-Object { $_ -ne '' })
            if ($parts.Count -ge 2 -and -not $map.ContainsKey($parts[0])) {
                $map[$parts[0]] = $parts[1]
            }
        }
        $map
    }
}

function Get-TaskwarriorAbbreviationMinimum {
    $map = Get-TaskwarriorShowMap
    $value = 0
    if ($map.ContainsKey('abbreviation.minimum')) {
        [void][int]::TryParse([string]$map['abbreviation.minimum'], [ref]$value)
    }
    if ($value -le 0) {
        $value = 2
    }
    return $value
}

function Get-TaskwarriorContextAliases {
    # Names of aliases that expand to a context command (alias.<name>=context).
    Get-TaskwarriorCompletionCacheEntry 'context-aliases' {
        $names = @()
        $map = Get-TaskwarriorShowMap
        foreach ($name in @($map.Keys)) {
            if ($name -like 'alias.*' -and [string]$map[$name] -match 'context') {
                if ($name -match '^alias\.([^.]+)') {
                    $names += $Matches[1]
                }
            }
        }
        $names
    }
}

function Get-TaskwarriorCommandNames {
    @(Get-TaskwarriorCompletionCacheEntry 'commands' {
        Invoke-TaskwarriorCompletionHelper @('_commands')
    })
}

function Get-TaskwarriorCommandDescriptions {
    # Name -> description map from "_zshcommands" (name:category:description).
    Get-TaskwarriorCompletionCacheEntry 'command-descriptions' {
        $map = @{}
        foreach ($line in (Invoke-TaskwarriorCompletionHelper @('_zshcommands'))) {
            $parts = @($line -split ':', 3)
            if ($parts.Count -ge 3 -and -not $map.ContainsKey($parts[0])) {
                $map[$parts[0]] = $parts[2]
            }
        }
        $map
    }
}

function Get-TaskwarriorAliasNames {
    @(Get-TaskwarriorCompletionCacheEntry 'aliases' {
        Invoke-TaskwarriorCompletionHelper @('_aliases')
    })
}

function Get-TaskwarriorColumns {
    @(Get-TaskwarriorCompletionCacheEntry 'columns' {
        Invoke-TaskwarriorCompletionHelper @('_columns')
    })
}

function Get-TaskwarriorTags {
    @(Get-TaskwarriorCompletionCacheEntry 'tags' {
        Invoke-TaskwarriorCompletionHelper @('_tags')
    })
}

function Get-TaskwarriorProjects {
    @(Get-TaskwarriorCompletionCacheEntry 'projects' {
        Invoke-TaskwarriorCompletionHelper @('_projects')
    })
}

function Get-TaskwarriorContextNames {
    @(Get-TaskwarriorCompletionCacheEntry 'contexts' {
        Invoke-TaskwarriorCompletionHelper @('_context')
    })
}

function Get-TaskwarriorConfigNames {
    @(Get-TaskwarriorCompletionCacheEntry 'config' {
        Invoke-TaskwarriorCompletionHelper @('_config')
    })
}

function Get-TaskwarriorTaskIds {
    # Task IDs with descriptions, from "_zshids" (id:description).
    @(Get-TaskwarriorCompletionCacheEntry 'ids' {
        $items = @()
        foreach ($line in (Invoke-TaskwarriorCompletionHelper @('_zshids'))) {
            $parts = @($line -split ':', 2)
            if ($parts.Count -ge 1 -and $parts[0] -ne '') {
                $description = ''
                if ($parts.Count -ge 2) {
                    $description = $parts[1]
                }
                $items += @{ Id = $parts[0]; Description = $description }
            }
        }
        $items
    })
}

###############################################################################
# Completion helpers
###############################################################################

function New-TaskwarriorCompletion {
    param(
        [string]$Text,
        [string]$ToolTip = '',
        [string]$Type = 'Text'
    )

    if (-not $Text) {
        return $null
    }
    if (-not $ToolTip) {
        $ToolTip = $Text
    }

    $completionText = $Text
    if ($completionText -match '\s') {
        $completionText = '"' + ($completionText -replace '"', '\"') + '"'
    }

    $resultType = [System.Management.Automation.CompletionResultType]::$Type
    return New-Object System.Management.Automation.CompletionResult -ArgumentList $completionText, $Text, $resultType, $ToolTip
}

function ConvertTo-TaskwarriorCompletionResults {
    # Items are hashtables: @{ Value; ToolTip; Type }
    param([object[]]$Items)

    $results = @()
    $seen = @{}
    foreach ($item in @($Items)) {
        if ($null -eq $item) {
            continue
        }
        $text = [string]$item.Value
        if ($text -eq '') {
            continue
        }
        $key = $text.ToLowerInvariant()
        if ($seen.ContainsKey($key)) {
            continue
        }
        $seen[$key] = $true

        $type = 'Text'
        if ($item.Type) {
            $type = [string]$item.Type
        }
        $results += New-TaskwarriorCompletion -Text $text -ToolTip ([string]$item.ToolTip) -Type $type
    }
    return $results
}

function Resolve-TaskwarriorAttribute {
    # Resolve an attribute token (such as 'proje', 'project' or 'due.before')
    # to its canonical column name. Abbreviations must be unique and, unless
    # -IgnoreMinimum is given, at least rc.abbreviation.minimum characters
    # long. Returns $null when the token does not identify an attribute.
    param(
        [string]$Token,
        [switch]$IgnoreMinimum
    )

    if ([string]::IsNullOrEmpty($Token)) {
        return $null
    }

    $base = $Token
    $modifier = ''
    if ($Token -match '\.') {
        if ($Token -match '^([A-Za-z][A-Za-z0-9_]*)(\.[A-Za-z]+)$' -and
            $TaskwarriorAttributeModifiers -contains $Matches[2].Substring(1)) {
            $base = $Matches[1]
            $modifier = $Matches[2]
        } else {
            return $null
        }
    }

    $columns = Get-TaskwarriorColumns
    foreach ($column in $columns) {
        if ([string]::Equals($column, $base, [StringComparison]::OrdinalIgnoreCase)) {
            return @{ Name = $column; Modifier = $modifier }
        }
    }

    $found = @($columns | Where-Object { $_.StartsWith($base, [StringComparison]::OrdinalIgnoreCase) })
    if ($found.Count -eq 1) {
        if ($IgnoreMinimum -or $base.Length -ge (Get-TaskwarriorAbbreviationMinimum)) {
            return @{ Name = $found[0]; Modifier = $modifier }
        }
    }

    return $null
}

function Get-TaskwarriorAttributeValues {
    # Known values for an attribute name, as items @{ Value; ToolTip }.
    param([string]$Name)

    switch ($Name) {
        'project' {
            return @(Get-TaskwarriorProjects | ForEach-Object {
                @{ Value = $_; ToolTip = 'project name' }
            })
        }
        'priority' {
            return @($TaskwarriorPriorityValues)
        }
        'status' {
            return @($TaskwarriorStatusValues)
        }
        'depends' {
            return @(Get-TaskwarriorTaskIds | ForEach-Object {
                @{ Value = $_.Id; ToolTip = $_.Description }
            })
        }
        'recur' {
            return @($TaskwarriorRecurHints)
        }
        'limit' {
            return @()
        }
        default {
            if ($TaskwarriorDateAttributes -contains $Name) {
                return @($TaskwarriorDateHints)
            }
            return @()
        }
    }
}

function Get-TaskwarriorPathCompletions {
    # File system completions for a partially typed path.
    param(
        [string]$Partial,
        [switch]$DirectoriesOnly
    )

    $prefix = ''
    $leaf = $Partial
    if ($Partial -match '^(.*[\\/])') {
        $prefix = $Matches[1]
        $leaf = $Partial.Substring($prefix.Length)
    }

    $searchPath = '.'
    if ($prefix -ne '') {
        $searchPath = $prefix
    }

    $results = @()
    $items = @(Get-ChildItem -LiteralPath $searchPath -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name.StartsWith($leaf, [StringComparison]::OrdinalIgnoreCase) })
    foreach ($item in $items) {
        if ($DirectoriesOnly -and -not $item.PSIsContainer) {
            continue
        }
        $path = $prefix + $item.Name
        if ($item.PSIsContainer) {
            $path += [IO.Path]::DirectorySeparatorChar
        }
        $results += @{ Value = $path; ToolTip = $path }
    }
    return $results
}

###############################################################################
# The completion routine
###############################################################################

function Get-TaskwarriorCompletions {
    # Complete the last word of $Words, whose first word is the task command.
    param([string[]]$Words)

    $words = @($Words)
    $count = $words.Count
    $cur = ''
    $prev = ''
    $prev2 = ''
    if ($count -ge 1) { $cur = $words[$count - 1] }
    if ($count -ge 2) { $prev = $words[$count - 2] }
    if ($count -ge 3) { $prev2 = $words[$count - 3] }

    $items = @()

    # Tag names: +tag / -tag.  A Windows drive letter (C:\...) is not a
    # separator, so check for those before splitting words at colons.
    $isPathWord = $cur -match '^[A-Za-z]:[\\/]'

    if (-not $isPathWord -and ($cur.StartsWith('+') -or $cur.StartsWith('-'))) {
        $sign = $cur.Substring(0, 1)
        foreach ($tag in (Get-TaskwarriorTags)) {
            if (($sign + $tag).StartsWith($cur, [StringComparison]::OrdinalIgnoreCase)) {
                $items += @{ Value = $sign + $tag; ToolTip = 'tag' }
            }
        }
        return ConvertTo-TaskwarriorCompletionResults $items
    }

    # After the context command: its subcommands and known context names.
    $contextWords = @('cont', 'conte', 'contex', 'context') + @(Get-TaskwarriorContextAliases)
    if ($contextWords -contains $prev) {
        foreach ($name in $TaskwarriorContextCommands) {
            if ($name.StartsWith($cur, [StringComparison]::OrdinalIgnoreCase)) {
                $items += @{ Value = $name; ToolTip = 'context command' }
            }
        }
        foreach ($name in (Get-TaskwarriorContextNames)) {
            if ($name.StartsWith($cur, [StringComparison]::OrdinalIgnoreCase)) {
                $items += @{ Value = $name; ToolTip = 'context' }
            }
        }
        return ConvertTo-TaskwarriorCompletionResults $items
    }

    # Attribute values combined into a single word: attr:value (the usual
    # form in PowerShell), including rc:<file> and rc.data.location:<dir>.
    if (-not $isPathWord -and $cur -match '^([^:]+):(.*)$') {
        $attrPart = $Matches[1]
        $valPart = $Matches[2]

        if ($attrPart -eq 'rc') {
            foreach ($item in (Get-TaskwarriorPathCompletions $valPart)) {
                $items += @{ Value = 'rc:' + $item.Value; ToolTip = $item.ToolTip }
            }
            return ConvertTo-TaskwarriorCompletionResults $items
        }
        if ($attrPart -eq 'rc.data.location') {
            foreach ($item in (Get-TaskwarriorPathCompletions $valPart -DirectoriesOnly)) {
                $items += @{ Value = 'rc.data.location:' + $item.Value; ToolTip = $item.ToolTip }
            }
            return ConvertTo-TaskwarriorCompletionResults $items
        }

        $attribute = Resolve-TaskwarriorAttribute -Token $attrPart -IgnoreMinimum
        if ($attribute) {
            foreach ($value in (Get-TaskwarriorAttributeValues $attribute.Name)) {
                if ($value.Value.StartsWith($valPart, [StringComparison]::OrdinalIgnoreCase)) {
                    $items += @{ Value = $attrPart + ':' + $value.Value; ToolTip = $value.ToolTip }
                }
            }
            return ConvertTo-TaskwarriorCompletionResults $items
        }
    }

    # Attribute values given as separate words around a colon: "attr : val".
    # This mirrors the bash completion, where ':' is a word break character.
    $attrToken = $null
    if ($cur -eq ':') {
        $attrToken = $prev
    } elseif ($prev -eq ':') {
        $attrToken = $prev2
    } elseif ($prev.EndsWith(':')) {
        $attrToken = $prev.TrimEnd(':')
    }

    if ($null -ne $attrToken -and $attrToken -ne '') {
        if ($attrToken -eq 'rc') {
            foreach ($item in (Get-TaskwarriorPathCompletions $cur)) {
                $items += $item
            }
            return ConvertTo-TaskwarriorCompletionResults $items
        }
        if ($attrToken -eq 'rc.data.location') {
            foreach ($item in (Get-TaskwarriorPathCompletions $cur -DirectoriesOnly)) {
                $items += $item
            }
            return ConvertTo-TaskwarriorCompletionResults $items
        }

        $attribute = Resolve-TaskwarriorAttribute -Token $attrToken
        if ($attribute) {
            foreach ($value in (Get-TaskwarriorAttributeValues $attribute.Name)) {
                if ($value.Value.StartsWith($cur, [StringComparison]::OrdinalIgnoreCase)) {
                    $items += $value
                }
            }
            return ConvertTo-TaskwarriorCompletionResults $items
        }
    }

    # Configuration variable names: rc.<variable>:
    if ($cur.StartsWith('rc.')) {
        foreach ($name in (Get-TaskwarriorConfigNames)) {
            $candidate = 'rc.' + $name + ':'
            if ($candidate.StartsWith($cur, [StringComparison]::OrdinalIgnoreCase)) {
                $items += @{ Value = $candidate; ToolTip = 'configuration override' }
            }
        }
        return ConvertTo-TaskwarriorCompletionResults $items
    }

    # File names after "import".
    if ($prev -eq 'import') {
        foreach ($item in (Get-TaskwarriorPathCompletions $cur)) {
            $items += $item
        }
        return ConvertTo-TaskwarriorCompletionResults $items
    }

    # Subcommands, aliases, and attribute names.
    $descriptions = Get-TaskwarriorCommandDescriptions
    foreach ($name in (Get-TaskwarriorCommandNames)) {
        if ($name.StartsWith($cur, [StringComparison]::OrdinalIgnoreCase)) {
            $tip = 'command'
            if ($descriptions.ContainsKey($name)) {
                $tip = $descriptions[$name]
            }
            $type = 'Command'
            if ($name.StartsWith('_')) {
                $type = 'Text'
            }
            $items += @{ Value = $name; ToolTip = $tip; Type = $type }
        }
    }
    foreach ($name in (Get-TaskwarriorAliasNames)) {
        if ($name.StartsWith($cur, [StringComparison]::OrdinalIgnoreCase)) {
            $items += @{ Value = $name; ToolTip = 'alias'; Type = 'Command' }
        }
    }
    foreach ($name in (Get-TaskwarriorColumns)) {
        $candidate = $name + ':'
        if ($candidate.StartsWith($cur, [StringComparison]::OrdinalIgnoreCase)) {
            $tip = 'attribute'
            if ($TaskwarriorAttributeDescriptions.ContainsKey($name)) {
                $tip = $TaskwarriorAttributeDescriptions[$name]
            }
            $items += @{ Value = $candidate; ToolTip = $tip }
        }
    }

    return ConvertTo-TaskwarriorCompletionResults $items
}

###############################################################################
# Registration
###############################################################################

Register-ArgumentCompleter -Native -CommandName task, task.exe -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)

    $words = @()
    foreach ($element in $commandAst.CommandElements) {
        if ($element -is [System.Management.Automation.Language.StringConstantExpressionAst] -or
            $element -is [System.Management.Automation.Language.ExpandableStringExpressionAst]) {
            $words += [string]$element.Value
        } else {
            $words += $element.Extent.Text
        }
    }

    # The last element is the word being completed; replace it by the partial
    # text under the cursor.
    if ($wordToComplete -ne '' -and $words.Count -gt 0 -and
        $words[$words.Count - 1].EndsWith($wordToComplete)) {
        if ($words.Count -ge 2) {
            $words = $words[0..($words.Count - 2)]
        } else {
            $words = @()
        }
    }
    $words += $wordToComplete

    Get-TaskwarriorCompletions -Words $words
}

###############################################################################
# When invoked as a script (not dot-sourced), print the completions for the
# given words, one per line.  This is used by test/powershell_completion.test.py
# to drive the routines without a console.
###############################################################################

if ($MyInvocation.InvocationName -ne '.' -and $args.Count -gt 0) {
    $testWords = @($args | ForEach-Object { [string]$_ })
    foreach ($completion in (Get-TaskwarriorCompletions -Words $testWords)) {
        Write-Output $completion.CompletionText
    }
    return
}
