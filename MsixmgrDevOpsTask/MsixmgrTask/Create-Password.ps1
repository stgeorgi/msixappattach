# From: https://powersnippets.com/create-string/
param (                                    
    [Int]$Size = 8,
    [Char[]]$Complexity = "ULNS",
    [Char[]]$Exclude
)

$AllTokens = @(); $Chars = @(); $TokenSets = @{
    UpperCase = [Char[]]'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    LowerCase = [Char[]]'abcdefghijklmnopqrstuvwxyz'
    Numbers   = [Char[]]'0123456789'
    Symbols   = [Char[]]'!"#$%&''()*+,-./:;<=>?@[\]^_`{|}~'
}
$TokenSets.Keys | Where-Object { $Complexity -Contains $_[0] } | ForEach-Object {
    $TokenSet = $TokenSets.$_ | Where-Object { $Exclude -cNotContains $_ } | ForEach-Object { $_ }
    If ($_[0] -cle "Z") { $Chars += $TokenSet | Get-Random }    #Character sets defined in uppercase are mandatory
    $AllTokens += $TokenSet
}
While ($Chars.Count -lt $Size) { $Chars += $AllTokens | Get-Random }
($Chars | Sort-Object { Get-Random }) -Join ""                #Mix the (mandatory) characters and output string
