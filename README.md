# Agendar migracion de Sharepoint
## Checklist antes de empezar
* Powershell 
* Sharegate 
* Usuario con  "Log on as a batch job" opcion habilitada.
* Lista de sitios a migrar.
* Generar el SecureString con el PassPath script.
* Tener completo el archivo .csv de la lista de Migraciones

## Descripcion del script
Permite agendar migraciones usando el Windows Task Scheduler para que se ejecuten en la tarde/noche, aun cuando el usuario no esta loggeado en la computadora. Las migraciones se ejecutan en fila una despues de otra y se genera un archivo con los logs del proceso.

### Acceso al archivo csv
En la parte de arriba del script vienen los paths de los diferentes archivos que se usan durante la ejecucion del mismo.
```Powershell
$Logs = "C:\Users\paul.vazquez\Documents\Logs\Logs.txt"
$PassPath = "C:\Users\paul.vazquez\Desktop\PassPath.txt"
$Sites = Import-Csv "C:\Users\paul.vazquez\Documents\QueueTest.csv"
$currentUser = "Paul Vazquez"
````
*Se tienen que modificar para cada usuario*. </br>
El archivo PassPath es un archivo de texto que contiene la contrasena de acceso a Sharepoint de forma "segura" pues se genero al convertirla de string a securestring y luego otra vez a string para guardarla en el txt. Se genera con el script PassPath.
### Migraciones
```Powershell
foreach ($line in $Sites){
    if(($line.("Status") -ne "MIGRATED") -and ($line.("Status") -ne "SKIP") ){
        $ID = $line.("ID")
        if($line.("AssignedTo") -eq $currentUser ){
            $Name = $line.("Name")
            Write-Log "ID:$ID  $Name"
            Migrate-Site -src $line.("SourceSite") -dst $line.("NewParentSite")
            $line.Status = "MIGRATED"
        }
        else{
            Write-Log "El sitio con ID: $ID no esta asignado a $currentUser"
        }
```
Revisa cada linea del .csv y realiza la migracion del sitio en la columna *SourceSite* a la columna *NewParentSite*. Cuando termina con ese renglon/sitio modifica la columna _Status_ a "MIGRATED" y se pasa al siguiente. ***OJO*** la columna _AssignedTo_ tiene que tener el nombre del usuario actual, eso lo puse como medida extra de seguridad para que no se me pasara poner algun sitio que Alejandra ya esta migrando y se hiciera un desastre /se duplicara.   
### Sharegate
```Powershell
Import-Module Sharegate	
    $UserName = "paul.vazquez@navico.com"
    $Password = Get-Content $PassPath
    $Password = ConvertTo-SecureString $Password
```
Se importa el modulo Sharegate y se guardan las credenciales que va a usar para conectarse al sitio de Sharepoint 2010 y Online.
```Powershell
$copysettings = New-CopySettings -OnContentItemExists IncrementalUpdate
```
Se guardan la configuracion de migracion en este caso le puse para que se hiciera _IncrementalUpdate_ en caso de que encuentre contenido ya existente en el sitio destino (es el equivalente al ***Copy if Newer (Incremental)*** en la herramienta.

```Powershell
$srcSite = Connect-Site -Url $src -UserName $UserName -Password $Password
$dstSite = Connect-Site -Url $dst -UserName $UserName -Password $Password
Write-Log "Source: $srcSite Destination: $dstSite"
```
Se conecta al sitio fuente/destino con las credenciales y se registra en el LogFile. Si no se logra conectar se imprime vacio el Source: Destination: en el LogFile y falla la migracion.
```Powershell
$result = Copy-Site -Site $srcSite -DestinationSite $dstSite -ForceNewListExperience -Subsites -CopySettings $copysettings
Write-Log $result.Result
Copy-ObjectPermissions -Source $srcSite -Destination $dstSite
```
El cmdlet Copy-Site es el clave en todo el script. Ahi es donde se ejecuta la migracion y se establecen algunos parametros que tambien se ponian en la herramienta. _-ForcenewListExperience_ es para la nueva experiencia de listas de Sharepoint Online. _-Subsites_ para que el sitio se copie como subsitio del sitio destino (Por eso se llama *New***Parent***Site*). Esta la opcion de agregar _-InsaneMode_ pero no la recomiendo porque luego falla desde Powershell.
El _Copy-ObjectPermissions_ es para que se copien los permisos del sitio.
```Powershell
$Sites | Export-Csv -Path 'C:\Users\paul.vazquez\Documents\UCSVTestFile-temp.csv' -NoTypeInformation 
Remove-Item -Path 'C:\Users\paul.vazquez\Documents\QueueTest.csv'
Rename-Item -Path 'C:\Users\paul.vazquez\Documents\UCSVTestFile-temp.csv' -NewName 'QueueTest.csv'
```
El script va guardando las modificaciones en un archivo temporal y luego las exporta en csv. De esta forma se va teniendo registro de cuales sitios ya se migraron para que en la siguiente ejecucion no se repitan migraciones (Columna Status)
## Especificaciones del documento .csv
El script revisa cada renglon del documento secuencialmente. Es necesario que existan las siguientes columnas para que funcione.

| Columna | Descripcion |
| --- | --- |
|  ID | Un numero de identificacion de ese renglon. |
| Title | Titulo del sitio a migrar |
| SourceSite | URL de origen del sitio a migrar en navigator |
| NewParentSite | URL de destino del nuevo sitio padre en Sharepoint Online. |
| AssignedTo | El nombre del usuario actual (Tiene que ser igual al string que esta al principio del script).
|Status | Estatus de la migracion (Puede no contener info, pero tiene que estar la columna).
### Ejemplo
Ejemplo de como se veria un renglon del archivo csv (Tiene columnas extras porque lo exporte directamente de la lista "Sitios a Migrar" de Sharepoint Online). No afectan. <br>
| ID | Title                           | SourceSite                                                 | AssignedTo   |  Owner         | To Do          | Status   | Notes | Priority | ParentSite                                            | Item Type | Path                                 | NewParentSite                      |
|----|---------------------------------|------------------------------------------------------------|--------------|----------------|----------------|----------|-------|----------|-------------------------------------------------------|-----------|--------------------------------------|------------------------------------|
| 0  | Boat Builder Excellence Program | http://navigator/sites/pmo/Projects/Special_Projects/BBEP/ | Paul Vazquez | Laurie Fernald | Migrate to SPO | MIGRATED |       | 3        | http://navigator/sites/pmo/Projects/Special_Projects/ | Item      | sites/global/it/Lists/MigrationSites | https://navico.sharepoint.com/test |

## Links
### Scripts

[Script de powershell] (https://codeshare.io/5ovA8X) <br>
[Script PassPath] (https://codeshare.io/GL64Ve) <br>

## Windows Task Scheduler
Para que el script se ejecute en horario fuera de oficina es necesario agendar una tarea en el Windows Task Scheduler con la hora de ejecucion y los parametros del programa.<br>
![logo] (https://preview.ibb.co/h6Qowd/0.png) 



 













