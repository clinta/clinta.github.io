---
layout: post
title: Changing UPN to Email with Powershell
date: 2015-06-30 14:20:00
---

If you need a quick way to change the UPN of all your users in active directory to match their email address, PowerShell makes it easy.

```powershell
$users = get-aduser -SearchBase "OU=Users,DC=ad,DC=contoso,DC=com" -Filter * -Properties EmailAddress | where {$_.EmailAddress -ne $null -AND $_.EmailAddress.toLower() -ne $_.UserPrincipalName.toLower()}

foreach ($user in $users) {
    $forest = Get-ADForest
    $email = $user.EmailAddress
    $username = $email.toLower().Split('@')[0]
    $userdomain = $email.toLower().Split('@')[1]
    if (-Not $forest.Contains($userdomain)) {
        $forest | Set-ADForest -UPNSuffixes @{Add="$userdomain"}
    }
    $user | Set-ADUser -UserPrincipalName "$username@$userdomain"
}
```
