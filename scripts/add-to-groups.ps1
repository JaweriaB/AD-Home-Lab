# add-to-groups.ps1
# Assigns AD users to Security Groups based on their department OU
# Author: Jaweria Batool
# GitHub: https://github.com/JaweriaB
#
# Run as Domain Admin on Domain Controller

Import-Module ActiveDirectory

$domain = "DC=corp,DC=local"

# --- Security Group to Department mapping ---
$groupMap = @{
    "IT"         = "IT-Staff"
    "HR"         = "HR-Staff"
    "Finance"    = "Finance-Staff"
    "Management" = "Managers"
}

Write-Host "=== AD Group Assignment ===" -ForegroundColor Cyan
Write-Host "Domain: $domain`n"

# --- Ensure Groups OU exists (create if missing) ---
$groupsOUPath = "OU=Groups,$domain"
if (-not (Get-ADOrganizationalUnit -Filter "Name -eq 'Groups'" -SearchBase $domain -ErrorAction SilentlyContinue)) {
    New-ADOrganizationalUnit -Name "Groups" -Path $domain
    Write-Host "[+] Created OU: Groups" -ForegroundColor Green
} else {
    Write-Host "[*] OU Groups already exists." -ForegroundColor Gray
}

# --- Ensure Security Groups exist inside Groups OU ---
foreach ($groupName in $groupMap.Values) {
    if (-not (Get-ADGroup -Filter "Name -eq '$groupName'" -ErrorAction SilentlyContinue)) {
        try {
            New-ADGroup `
                -Name          $groupName `
                -GroupScope    Global `
                -GroupCategory Security `
                -Path          $groupsOUPath
            Write-Host "[+] Created group: $groupName" -ForegroundColor Green
        }
        catch {
            Write-Host "[-] Failed to create group $groupName : $_" -ForegroundColor Red
        }
    } else {
        Write-Host "[*] Group already exists: $groupName" -ForegroundColor Gray
    }
}

Write-Host ""

# --- Assign users to groups by department OU ---
foreach ($dept in $groupMap.Keys) {
    $ouPath = "OU=$dept,$domain"
    $group  = $groupMap[$dept]

    # Check OU exists before querying
    if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$dept'" -ErrorAction SilentlyContinue)) {
        Write-Host "[!] OU not found: $dept — skipping." -ForegroundColor Yellow
        continue
    }

    $users = @(Get-ADUser -Filter * -SearchBase $ouPath -ErrorAction SilentlyContinue)

    if ($users.Count -eq 0) {
        Write-Host "[!] No users found in OU: $dept" -ForegroundColor Yellow
        continue
    }

    foreach ($user in $users) {
        try {
            Add-ADGroupMember -Identity $group -Members $user.SamAccountName -ErrorAction Stop
            Write-Host "[+] Added $($user.SamAccountName) → $group" -ForegroundColor Green
        }
        catch [Microsoft.ActiveDirectory.Management.ADException] {
            # User already in group — not a real error
            Write-Host "[*] $($user.SamAccountName) already in $group" -ForegroundColor Gray
        }
        catch {
            Write-Host "[-] Failed for $($user.SamAccountName): $_" -ForegroundColor Red
        }
    }
}

Write-Host "`n[Done] Group assignments complete." -ForegroundColor Cyan
