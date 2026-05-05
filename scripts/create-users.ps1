# create-users.ps1
# Bulk creates Active Directory users from a CSV file
# Author: Jaweria Batool
# GitHub: https://github.com/JaweriaB
#
# SECURITY NOTE: This script reads passwords from a CSV file in plain text.
# This is intentional for lab/demo environments only.
# In production, use a secrets manager (e.g. CyberArk, Azure Key Vault)
# or prompt for passwords interactively using Read-Host -AsSecureString.
#
# Usage: Run as Domain Admin on Domain Controller
#   .\create-users.ps1
#   .\create-users.ps1 -CsvPath "D:\myusers.csv"

param(
    [string]$CsvPath = "$PSScriptRoot\users.csv"
)

# --- Configuration ---
$domain = "DC=corp,DC=local"

# --- Import AD Module ---
Import-Module ActiveDirectory

# --- Validate CSV path ---
if (-not (Test-Path $CsvPath)) {
    Write-Host "[-] CSV file not found: $CsvPath" -ForegroundColor Red
    Write-Host "    Place users.csv in the same folder as this script, or use:" -ForegroundColor Yellow
    Write-Host "    .\create-users.ps1 -CsvPath 'C:\path\to\users.csv'" -ForegroundColor Yellow
    exit 1
}

Write-Host "=== AD Bulk User Creation ===" -ForegroundColor Cyan
Write-Host "CSV     : $CsvPath"
Write-Host "Domain  : $domain"
Write-Host "[!] WARNING: Passwords are read from plain-text CSV. Lab use only.`n" -ForegroundColor Yellow

# --- Ensure department OUs exist ---
$departments = @("IT", "HR", "Finance", "Management")
foreach ($dept in $departments) {
    if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$dept'" -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name $dept -Path $domain
        Write-Host "[+] Created OU: $dept" -ForegroundColor Green
    }
}

# --- Create Users from CSV ---
$users = Import-Csv $CsvPath
$successCount = 0
$failCount = 0

foreach ($user in $users) {
    $samAccount = $user.Username
    $upn        = "$samAccount@corp.local"
    $ouPath     = "OU=$($user.Department),$domain"

    # Validate password field is not empty
    if ([string]::IsNullOrWhiteSpace($user.Password)) {
        Write-Host "[-] Skipping $samAccount — password field is empty in CSV." -ForegroundColor Red
        $failCount++
        continue
    }

    $securePass = ConvertTo-SecureString $user.Password -AsPlainText -Force

    # Check if user already exists
    if (Get-ADUser -Filter "SamAccountName -eq '$samAccount'" -ErrorAction SilentlyContinue) {
        Write-Host "[!] Already exists: $samAccount" -ForegroundColor Yellow
        continue
    }

    try {
        New-ADUser `
            -Name                 "$($user.FirstName) $($user.LastName)" `
            -GivenName            $user.FirstName `
            -Surname              $user.LastName `
            -SamAccountName       $samAccount `
            -UserPrincipalName    $upn `
            -Path                 $ouPath `
            -AccountPassword      $securePass `
            -Enabled              $true `
            -PasswordNeverExpires $false `
            -ChangePasswordAtLogon $true

        Write-Host "[+] Created: $samAccount in OU=$($user.Department)" -ForegroundColor Green
        $successCount++
    }
    catch {
        Write-Host "[-] Failed to create $samAccount : $_" -ForegroundColor Red
        $failCount++
    }
}

Write-Host "`n--- Summary ---"
Write-Host "Created : $successCount users" -ForegroundColor Green
Write-Host "Failed  : $failCount users"    -ForegroundColor Red
