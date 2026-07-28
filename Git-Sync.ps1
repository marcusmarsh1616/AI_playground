#Requires -Version 5.1
<#
.SYNOPSIS
    Interactive Git repository synchronization tool

.DESCRIPTION
    Provides a menu-driven interface for syncing the local repository with the remote GitHub repository.
    Features:
    - Pull updates from remote
    - Push local commits (with auto-commit of uncommitted changes)
    - Full sync (pull + push)
    - View repository status
    - Automatic timestamp commits for uncommitted changes

.NOTES
    Repository: AI_Playground
    Remote: https://github.com/marcusmarsh1616/AI_Playground.git
    Author: Claude Code
    Date: 2026-07-28
#>

# Set working directory to repository root
Set-Location "C:\Temp\AI_playground\SimpleGit"

# Function to display the main menu
function Show-Menu {
    Clear-Host
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "   Git Repository Sync Tool" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Repository: " -NoNewline
    Write-Host "AI_Playground" -ForegroundColor Yellow

    # Get current branch
    $branch = git rev-parse --abbrev-ref HEAD 2>$null
    Write-Host "Branch: " -NoNewline
    Write-Host "$branch" -ForegroundColor Yellow

    # Get status summary
    $status = git status --porcelain 2>$null
    if ($status) {
        $fileCount = ($status | Measure-Object).Count
        Write-Host "Status: " -NoNewline
        Write-Host "$fileCount file(s) modified" -ForegroundColor Yellow
    } else {
        Write-Host "Status: " -NoNewline
        Write-Host "Clean working tree" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "[1] Pull (Download updates from remote)" -ForegroundColor White
    Write-Host "[2] Push (Upload commits to remote)" -ForegroundColor White
    Write-Host "[3] Full Sync (Pull + Push)" -ForegroundColor White
    Write-Host "[4] Status (View detailed status)" -ForegroundColor White
    Write-Host "[5] Exit" -ForegroundColor White
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
}

# Function to get and display detailed repository status
function Get-RepoStatus {
    Write-Host ""
    Write-Host "=== Repository Status ===" -ForegroundColor Cyan
    Write-Host ""

    # Current branch
    $branch = git rev-parse --abbrev-ref HEAD 2>$null
    Write-Host "Current Branch: " -NoNewline
    Write-Host "$branch" -ForegroundColor Yellow

    # Last commit
    $lastCommit = git log -1 --pretty=format:"%h - %s (%cr)" 2>$null
    Write-Host "Last Commit: " -NoNewline
    Write-Host "$lastCommit" -ForegroundColor Yellow

    # Check ahead/behind status
    git fetch origin 2>$null
    $ahead = git rev-list --count origin/$branch..$branch 2>$null
    $behind = git rev-list --count $branch..origin/$branch 2>$null

    if ($ahead -gt 0) {
        Write-Host "Ahead of remote: " -NoNewline
        Write-Host "$ahead commit(s)" -ForegroundColor Green
    }
    if ($behind -gt 0) {
        Write-Host "Behind remote: " -NoNewline
        Write-Host "$behind commit(s)" -ForegroundColor Yellow
    }
    if ($ahead -eq 0 -and $behind -eq 0) {
        Write-Host "Sync Status: " -NoNewline
        Write-Host "Up to date with remote" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Working Tree Status:" -ForegroundColor Cyan
    git status --short

    Write-Host ""
}

# Function to pull updates from remote
function Invoke-Pull {
    Write-Host ""
    Write-Host "=== Pulling from Remote ===" -ForegroundColor Cyan
    Write-Host ""

    # Check for uncommitted changes
    $status = git status --porcelain 2>$null
    if ($status) {
        Write-Host "Warning: You have uncommitted changes." -ForegroundColor Yellow
        Write-Host "Stashing changes before pull..." -ForegroundColor Yellow
        git stash push -m "Auto-stash before pull $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        $stashed = $true
    }

    # Pull from remote
    $branch = git rev-parse --abbrev-ref HEAD 2>$null
    Write-Host "Pulling from origin/$branch..." -ForegroundColor White

    $pullOutput = git pull origin $branch 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "Pull completed successfully!" -ForegroundColor Green
        Write-Host $pullOutput

        # Pop stash if we stashed
        if ($stashed) {
            Write-Host ""
            Write-Host "Restoring stashed changes..." -ForegroundColor Yellow
            git stash pop
        }
    } else {
        Write-Host ""
        Write-Host "Pull failed!" -ForegroundColor Red
        Write-Host $pullOutput

        if ($pullOutput -like "*CONFLICT*") {
            Write-Host ""
            Write-Host "Merge conflict detected. Please resolve conflicts manually." -ForegroundColor Red
        }
    }

    Write-Host ""
}

# Function to push commits to remote
function Invoke-Push {
    Write-Host ""
    Write-Host "=== Pushing to Remote ===" -ForegroundColor Cyan
    Write-Host ""

    # Check for uncommitted changes and auto-commit
    $status = git status --porcelain 2>$null
    if ($status) {
        Write-Host "Uncommitted changes detected. Auto-committing..." -ForegroundColor Yellow
        Write-Host ""

        # Show what will be committed
        Write-Host "Files to be committed:" -ForegroundColor Cyan
        git status --short
        Write-Host ""

        # Stage all changes
        git add -A

        # Create commit with timestamp
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $commitMsg = "Auto-sync $timestamp"

        git commit -m $commitMsg

        if ($LASTEXITCODE -eq 0) {
            Write-Host "Changes committed: $commitMsg" -ForegroundColor Green
        } else {
            Write-Host "Commit failed!" -ForegroundColor Red
            return
        }
    }

    # Check if there's anything to push
    $branch = git rev-parse --abbrev-ref HEAD 2>$null
    $ahead = git rev-list --count origin/$branch..$branch 2>$null

    if ($ahead -eq 0) {
        Write-Host "Nothing to push. Local branch is up to date with remote." -ForegroundColor Yellow
        Write-Host ""
        return
    }

    # Push to remote
    Write-Host "Pushing $ahead commit(s) to origin/$branch..." -ForegroundColor White

    $pushOutput = git push origin $branch 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "Push completed successfully!" -ForegroundColor Green
        Write-Host $pushOutput
    } else {
        Write-Host ""
        Write-Host "Push failed!" -ForegroundColor Red
        Write-Host $pushOutput

        if ($pushOutput -like "*rejected*") {
            Write-Host ""
            Write-Host "Push rejected. Try pulling first to get remote changes." -ForegroundColor Yellow
        }
    }

    Write-Host ""
}

# Function to perform full sync (pull + push)
function Invoke-FullSync {
    Write-Host ""
    Write-Host "=== Full Sync (Pull + Push) ===" -ForegroundColor Cyan
    Write-Host ""

    # First, pull from remote
    Write-Host "Step 1: Pulling from remote..." -ForegroundColor Cyan
    Invoke-Pull

    # Wait a moment
    Start-Sleep -Seconds 1

    # Then, push to remote
    Write-Host "Step 2: Pushing to remote..." -ForegroundColor Cyan
    Invoke-Push

    Write-Host "Full sync completed!" -ForegroundColor Green
    Write-Host ""
}

# Main loop
$continue = $true

while ($continue) {
    Show-Menu

    $choice = Read-Host "Select option (1-5)"

    switch ($choice) {
        "1" {
            Invoke-Pull
            Write-Host "Press any key to continue..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        "2" {
            Invoke-Push
            Write-Host "Press any key to continue..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        "3" {
            Invoke-FullSync
            Write-Host "Press any key to continue..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        "4" {
            Get-RepoStatus
            Write-Host "Press any key to continue..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        "5" {
            Write-Host ""
            Write-Host "Exiting Git Sync Tool. Goodbye!" -ForegroundColor Cyan
            Write-Host ""
            $continue = $false
        }
        default {
            Write-Host ""
            Write-Host "Invalid option. Please select 1-5." -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
    }
}
