---
layout: single
title: Changing UPN to Email with Powershell
date: 2015-08-07
slug: Change-UPN-To-Email-with-Powershell
aliases:
  - 2015-08-07-Change-UPN-To-Email-with-Powershell
  - 2015-8-07-Change-UPN-To-Email-with-Powershell
  - 2015-8-7-Change-UPN-To-Email-with-Powershell
---

If you need a quick way to change the UPN of all your users in active directory to match their email address, PowerShell makes it easy.

```powershell
$users = get-aduser -SearchBase "OU=Users,DC=ad,DC=contoso,DC=com" -Filter * -Properties EmailAddress |
where {$_.EmailAddress -ne $null -AND $_.EmailAddress.toLower() -ne $_.UserPrincipalName.toLower()}

foreach ($user in $users) {
    $forest = Get-ADForest
    $email = $user.EmailAddress
    $username = $email.toLower().Split('@')[0]
    $userdomain = $email.toLower().Split('@')[1]
    if (-Not $($forest.UPNSuffixes).Contains($userdomain)) {
        $forest | Set-ADForest -UPNSuffixes @{Add="$userdomain"}
    }
    $user | Set-ADUser -UserPrincipalName "$username@$userdomain"
}
```
