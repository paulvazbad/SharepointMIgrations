$Password  = Read-Host -Prompt "Escribe tu contraseña"
$SecurePassword   = ConvertTo-SecureString $Password -AsPlainText -Force
$Password  = ConvertFrom-SecureString $SecurePassword
echo $Password > PassPath.txt