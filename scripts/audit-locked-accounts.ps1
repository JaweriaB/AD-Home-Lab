# audit-locked-accounts.ps1
# Reports all locked-out AD accounts and optionally unlocks them
# Author: Jaweria Batool
# GitHub: https://github.com/JaweriaB
#
# Run as Domain Admin on Domain Controller

Import-Module ActiveDirectory

Write-Host "=== AD Account Lockout Audit ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"

# --- Find all locked accounts ---
# @() forces array type — ensures .Count works correctly even with 0 or 1 result
$lockedAccounts = @(Search-ADAccount -LockedOut)

if ($lockedAccounts.Count -eq 0) {
    Write-Host "[OK] No locked accounts found." -ForegroundColor Green
    exit
}

Write-Host "Found $($lockedAccounts.Count) locked account(s):`n" -ForegroundColor Yellow

foreach ($account in $lockedAccounts) {
    $user = Get-ADUser -Identity $account.SamAccountName `
        -Properties LockedOut, BadLogonCount, LastBadPasswordAttempt, DistinguishedName

    Write-Host "User            : $($user.Name)"
    Write-Host "  SamAccountName: $($user.SamAccountName)"
    Write-Host "  Bad Attempts  : $($user.BadLogonCount)"
    Write-Host "  Last Bad Logon: $($user.LastBadPasswordAttempt)"
    Write-Host "  OU            : $($user.DistinguishedName -replace '^CN=.*?,' ,'')"
    Write-Host ""
}

# --- Optional: Unlock all ---
$unlock = Read-Host "Unlock all accounts? (y/N)"
if ($unlock -eq "y") {
    foreach ($account in $lockedAccounts) {
        Unlock-ADAccount -Identity $account.SamAccountName
        Write-Host "[+] Unlocked: $($account.SamAccountName)" -ForegroundColor Green
    }
    Write-Host "`n[Done] All accounts unlocked."
} else {
    Write-Host "[Skipped] No accounts were unlocked."
}
