#!/usr/bin/env pwsh

<#
.SYNOPSIS
    PowerShell version of Git submodule management, replicating `git-submodule.sh`.

.DESCRIPTION
    Uses `git submodule--helper` to execute submodule operations like the original shell script.

.PARAMETER Command
    The submodule command to execute (e.g., add, init, update, status, deinit).

.PARAMETER Path
    The path of the submodule.

.PARAMETER Repository
    The repository URL for adding a submodule.

.PARAMETER Branch
    The branch to use when adding a submodule.

.PARAMETER Reference
    A reference repository.

.PARAMETER Force
    Enables force options.

.PARAMETER Recursive
    Enables recursive options.

.PARAMETER Quiet
    Suppresses output.

.PARAMETER Init
    Initializes submodules.

.PARAMETER Remote
    Fetches changes from the remote repository.

.PARAMETER NoFetch
    Prevents fetching new commits.

.PARAMETER Checkout
    Uses "checkout" mode in updates.

.PARAMETER Merge
    Uses "merge" mode in updates.

.PARAMETER Rebase
    Uses "rebase" mode in updates.

.PARAMETER SingleBranch
    Fetches only one branch.

.EXAMPLE
    ./git-submodule.ps1 add --Repository "https://github.com/example/repo.git" --Path "submodules/my-submodule"
#>

# system wide setup:
# git config --global alias.submodule '!pwsh <PATH_TO_THIS_SCRIPT>/git-submodule.ps1'
# git submodule update --init --recursive

param(
    [string]$Command,
    [string]$Path,
    [string]$Repository,
    [string]$Branch,
    [string]$Reference,
    [switch]$Quiet,
    [switch]$Force,
    [switch]$Recursive,
    [switch]$Init,
    [switch]$Remote,
    [switch]$NoFetch,
    [switch]$Checkout,
    [switch]$Merge,
    [switch]$Rebase,
    [switch]$SingleBranch
)

$insideGitRepo = git rev-parse --is-inside-work-tree 2>$null
if ($insideGitRepo -ne "true") {
    Write-Host "Error: Not inside a Git repository." -ForegroundColor Red
    exit 1
}

$gitRoot = git rev-parse --show-toplevel
Set-Location $gitRoot

function Execute-GitSubmoduleHelper {
    param([string]$Subcommand, [string]$Arguments)
    $cmd = "git submodule--helper $Subcommand $Arguments"

    if ($Quiet) { $cmd += " --quiet" }
    if ($Force) { $cmd += " --force" }
    if ($Recursive) { $cmd += " --recursive" }

    Write-Host "Executing: $cmd"
    Invoke-Expression $cmd
}

switch ($Command) {
    "add" {
        if (-not $Repository -or -not $Path) {
            Write-Host "Usage: git-submodule.ps1 add --Repository <URL> --Path <Path>" -ForegroundColor Yellow
            exit 1
        }
        $args = "--name '$Path'"
        if ($Branch) { $args += " --branch '$Branch'" }
        if ($Reference) { $args += " --reference '$Reference'" }
        Execute-GitSubmoduleHelper "add" "$args '$Repository' '$Path'"
    }

    "init" {
        Execute-GitSubmoduleHelper "init" ""
    }

    "deinit" {
        if (-not $Path) {
            Write-Host "Usage: git-submodule.ps1 deinit --Path <Path>" -ForegroundColor Yellow
            exit 1
        }
        Execute-GitSubmoduleHelper "deinit" "--force '$Path'"
    }

    "update" {
        $args = ""
        if ($Init) { $args += "--init " }
        if ($Remote) { $args += "--remote " }
        if ($NoFetch) { $args += "-N " }
        if ($Rebase) { $args += "--rebase " }
        if ($Merge) { $args += "--merge " }
        if ($Checkout) { $args += "--checkout " }
        if ($SingleBranch) { $args += "--single-branch " }
        Execute-GitSubmoduleHelper "update" "$args '$Path'"
    }

    "status" {
        Execute-GitSubmoduleHelper "status" ""
    }

    "set-branch" {
        if (-not $Path -or -not $Branch) {
            Write-Host "Usage: git-submodule.ps1 set-branch --Path <Path> --Branch <Branch>" -ForegroundColor Yellow
            exit 1
        }
        Execute-GitSubmoduleHelper "set-branch" "--branch '$Branch' '$Path'"
    }

    "set-url" {
        if (-not $Path -or -not $NewUrl) {
            Write-Host "Usage: git-submodule.ps1 set-url --Path <Path> --NewUrl <URL>" -ForegroundColor Yellow
            exit 1
        }
        Execute-GitSubmoduleHelper "set-url" "'$Path' '$NewUrl'"
    }

    "summary" {
        Execute-GitSubmoduleHelper "summary" ""
    }

    "foreach" {
        if (-not $Path) {
            Write-Host "Usage: git-submodule.ps1 foreach --Path <command>" -ForegroundColor Yellow
            exit 1
        }
        Execute-GitSubmoduleHelper "foreach" "'$Path'"
    }

    "sync" {
        Execute-GitSubmoduleHelper "sync" ""
    }

    "absorbgitdirs" {
        Execute-GitSubmoduleHelper "absorbgitdirs" ""
    }

    default {
        Write-Host "Invalid command. Use: add, init, deinit, update, status, set-branch, set-url, summary, foreach, sync, absorbgitdirs" -ForegroundColor Red
        exit 1
    }
}