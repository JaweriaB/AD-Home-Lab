# Enterprise Identity Management Lab (Active Directory)

## Overview

This project involved designing and deploying a virtualized Windows Server environment to simulate a corporate network infrastructure. The goal was to master enterprise identity management, security policy enforcement, and network hierarchy — mirroring how organizations manage users and devices at scale.

The lab simulates a real-world scenario: an IT team managing a small company of 50+ employees with centralized authentication, enforced security policies, and managed network services.

---

## Tech Stack

| Component | Tool/Technology |
|---|---|
| Hypervisor | Oracle VirtualBox (free) / VMware Workstation |
| Domain Controller OS | Windows Server 2022 |
| Client Workstations | Windows 10 / Windows 11 |
| Scripting | PowerShell 5.1+ |
| Networking | NAT Network, Static IP, DNS, DHCP |

---

## Architecture

```
[ Domain Controller: WIN-SERVER2022 ]
         |   192.168.1.1
         |   DNS: 192.168.1.1
         |   DHCP: 192.168.1.100-200
         |
   ------+------+------
   |            |
[ Client-01 ]  [ Client-02 ]
  Win 10         Win 11
  192.168.1.101  192.168.1.102
```

---

## Key Features

### 1. Automated User Management (PowerShell)
- Bulk-created **50+ Active Directory users** from a CSV file using a PowerShell script
- Organized users into **Organizational Units (OUs)** by department: `IT`, `HR`, `Finance`, `Management`
- Assigned users to appropriate **Security Groups** for role-based access control

```powershell
# Sample snippet from user creation script
Import-Csv "C:\users.csv" | ForEach-Object {
    New-ADUser `
        -Name "$($_.FirstName) $($_.LastName)" `
        -GivenName $_.FirstName `
        -Surname $_.LastName `
        -SamAccountName $_.Username `
        -UserPrincipalName "$($_.Username)@corp.local" `
        -Path "OU=$($_.Department),DC=corp,DC=local" `
        -AccountPassword (ConvertTo-SecureString $_.Password -AsPlainText -Force) `
        -Enabled $true
    Write-Host "Created user: $($_.Username)"
}
```

### 2. Group Policy Objects (GPOs)
Implemented the following security policies across the domain:

| Policy | Scope | Description |
|---|---|---|
| Password Complexity | Domain-wide | Min 12 chars, uppercase, numbers, symbols |
| Account Lockout | Domain-wide | 5 failed attempts → 30 min lockout |
| Disable USB Storage | All Workstations | Block removable media via registry GPO |
| Desktop Wallpaper | All Users | Corporate branded wallpaper enforced |
| Windows Firewall | All Workstations | Enabled + block inbound by default |
| Software Restriction | HR/Finance OUs | Block execution from Downloads folder |

### 3. Network Services (DNS + DHCP)
- Configured **DNS Server** role on the Domain Controller for internal name resolution (`corp.local`)
- Set up **DHCP Server** with address pool `192.168.1.100 – 192.168.1.200`
- Added DHCP reservations for servers and printers using MAC addresses
- Verified domain join and DNS resolution from client machines

### 4. Remote Administration
- Enabled **Remote Desktop** for IT admin accounts via GPO
- Used **RSAT (Remote Server Administration Tools)** to manage AD from a client machine
- Configured **Windows Admin Center** for browser-based server management

---

## Setup Guide

### Prerequisites
- A host machine with at least **8GB RAM** (16GB recommended) and **50GB free disk space**
- Oracle VirtualBox (free): https://www.virtualbox.org/
- Windows Server 2022 Evaluation ISO (free 180-day trial from Microsoft)
- Windows 10/11 ISO

### Step 1: Create the Domain Controller VM
1. New VM → Windows 2022 → Assign **2 CPU cores, 2GB RAM, 40GB disk**
2. Install Windows Server 2022 (Desktop Experience)
3. Set a static IP: `192.168.1.1`, Subnet: `255.255.255.0`, DNS: `127.0.0.1`
4. Open **Server Manager → Add Roles and Features**
5. Install: `Active Directory Domain Services`, `DNS Server`, `DHCP Server`
6. Promote server to Domain Controller → Create new forest: `corp.local`
7. Reboot

### Step 2: Configure DHCP
1. Server Manager → Tools → DHCP
2. New Scope: `192.168.1.100 – 192.168.1.200`
3. Set gateway: `192.168.1.1`, DNS: `192.168.1.1`
4. Authorize DHCP server in AD

### Step 3: Create OUs and Users
1. Server Manager → Tools → Active Directory Users and Computers
2. Right-click domain → New → Organizational Unit → create: `IT`, `HR`, `Finance`
3. Run the PowerShell user-creation script (see `/scripts/create-users.ps1`)

### Step 4: Join Client Machines to Domain
1. Create client VMs (Windows 10/11), connect to same NAT Network
2. Set DNS on client to `192.168.1.1`
3. System Properties → Change → Domain: `corp.local`
4. Authenticate with Domain Admin credentials → Reboot

### Step 5: Apply GPOs
1. Server Manager → Tools → Group Policy Management
2. Right-click domain or specific OU → Create and Link GPO
3. Edit policy settings as needed (see Key Features section above)

---

## Scripts

```
AD-Home-Lab/
└── scripts/
    ├── create-users.ps1           # Bulk user creation from CSV
    ├── add-to-groups.ps1          # Assign users to Security Groups by OU
    ├── audit-locked-accounts.ps1  # Report on locked AD accounts
    └── users.csv                  # Sample user data for create-users.ps1
```

### Security Note — Plain-Text Passwords in CSV

The `create-users.ps1` script reads passwords from `users.csv` in plain text. This is a **deliberate lab design choice** — acceptable in an isolated virtual environment with no internet exposure.

In a production environment this would be replaced with:
- **Interactive prompts** using `Read-Host -AsSecureString`
- **A secrets manager** such as CyberArk, HashiCorp Vault, or Azure Key Vault
- **Active Directory's fine-grained password policies** for initial password generation

The script explicitly warns the operator at runtime that plain-text credentials are in use.

### Groups OU — Auto-Creation

`add-to-groups.ps1` automatically creates the `Groups` OU if it doesn't exist before attempting to place Security Groups inside it. This prevents the script from failing silently on a fresh domain where only the default OUs are present.

---

## What I Learned

- How enterprise environments structure **identity and access management**
- Real-world **PowerShell automation** for sysadmin tasks
- **GPO design** to enforce security baselines across a domain
- How **DNS and DHCP** integrate with Active Directory
- The relationship between **OUs, Security Groups, and GPOs**
- Why **plain-text credentials in scripts are a security risk** and how production environments mitigate this with secrets managers
- Importance of **defensive scripting** — validating that required OUs exist before operations that depend on them

---

## Challenges Overcome

These are real issues I ran into during the build and how I resolved them:

**1. Client machines couldn't find the domain during join**
After setting up the Domain Controller, the Windows 10 client kept returning *"domain corp.local could not be contacted."* The fix was realizing the client's DNS was still pointing to the VirtualBox default gateway (`10.0.2.1`) instead of the DC's static IP (`192.168.1.1`). Manually updating the DNS server in the client's IPv4 settings resolved it immediately.

**2. DHCP not handing out addresses to clients**
The DHCP scope was configured correctly but clients weren't receiving addresses. Turned out the DHCP server wasn't authorized in Active Directory — a step I'd skipped. Authorizing it through the DHCP console (right-click server → Authorize) fixed the issue.

**3. PowerShell script failing on special characters in passwords**
The bulk user creation script was throwing `ConvertTo-SecureString` errors for users whose generated passwords contained `&` or `<`. Wrapping the password field in the CSV with quotes and sanitizing input before passing to `ConvertTo-SecureString` resolved it.

**4. GPO not applying to client workstations**
A USB-disable policy I created wasn't being applied even after `gpupdate /force`. The issue was that the GPO was linked to the domain root but the workstations were in a sub-OU that had **Block Inheritance** enabled from a previous test. Removing that inheritance block fixed it.

---

## References

- [Microsoft AD DS Documentation](https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/get-started/virtual-dc/active-directory-domain-services-overview)
- [Josh Madakor's AD Lab Tutorial (YouTube)](https://www.youtube.com/watch?v=MHklaStSTg) — inspiration for this setup
- [VirtualBox Networking Guide](https://www.virtualbox.org/manual/ch06.html)

---

## Author

**Jaweria Batool**
Self-taught IT & Cybersecurity | Linux | Windows Server | PowerShell
[GitHub](https://github.com/JaweriaB) · [LinkedIn](https://www.linkedin.com/in/jaweria-b-263256398)
