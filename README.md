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
Ejemplo de como se veria un renglon del archivo csv (Tiene columnas extras porque lo exporte directamente de la lista "Sitios a Migrar" de Sharepoint Online). No afectan. **Cada renglon representa una columna, se transpuso para mejorar la visualizacion** <br>

| Columna       | Elemento                                                   |
|---------------|------------------------------------------------------------|
| ID            | 0                                                          |
| Title         | Boat Builder Excellence Program                            |
| SourceSite    | http://navigator/sites/pmo/Projects/Special_Projects/BBEP/ |
| AssignedTo    | Paul Vazquez                                               |
|  Owner        | Laurie Fernald                                             |
| To Do         | Migrate to SPO                                             |
| Status        | MIGRATED                                                   |
| Notes         |                                                            |
| Priority      | 3                                                          |
| ParentSite    | http://navigator/sites/pmo/Projects/Special_Projects/      |
| Item Type     | Item                                                       |
| Path          | sites/global/it/Lists/MigrationSites                       |
| NewParentSite | https://navico.sharepoint.com/test                         |

## Windows Taks Scheduler
Para que las migraciones se realizen automaticamente es necesario agendarlas a cierta hora en el windows Task Scheduler.
Estos son los pasos a seguir:
1. Abir el programa y seleccionar _Create Task_.
<img src="https://image.ibb.co/e1MmGd/0.png" alt="0" border="0">
2. En la seccion de _Create Task_ es importante habilitar la opcion de _Run wheter user is logged on or not_. <br>
<img src="https://image.ibb.co/mSD8wd/1.png" alt="1" border="0">
3. Luego de llenar esa ventana ir a la seccion de *Triggers* y seleccionar *New Trigger*. Seleccionar la hora de ejecucion. <br>
<img src="https://image.ibb.co/bujsNJ/2.png" alt="2" border="0">
4. Posteriormente acceder a la seccion de Actions y seleccionar *New Action*. En la opcion de _Program/Script_ escribir Powershell.exe y en _Add arguments_ incluir el path al script con terminacion .ps1 de las migraciones. <br>
<img src="https://image.ibb.co/dr1vbd/3.png" alt="3" border="0">
5. Finalmente en la pestaña de  *Conditions* seleccionar *Wake the computer to run this Task*.


## Links
### Scripts

[Script de migraciones](https://codeshare.io/5ovA8X) <br>
[Script de PassPath](https://codeshare.io/GL64Ve)
