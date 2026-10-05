# Fase 1: SQL Server (instalación, base de datos, tabla y usuario)

Esta fase deja listo el servidor de base de datos que usará la aplicación web del laboratorio. Al terminarla se tiene:

- SQL Server 2025 (Standard Developer) instalado en la VM Windows Server.
- SQL Server Management Studio (SSMS) para administrarlo.
- La base de datos `LabSQLi` con la tabla `Usuarios` y dos usuarios de prueba.
- Un inicio de sesión de SQL Server, `webuser`, con el que se conectará la aplicación.

> **Entorno:** VM Windows Server (nombre de equipo `WIN-5OCEJPK16SB`), red NAT aislada. Todas las capturas se tomaron el 2/10/2026 (instalación) y el 4/10/2026 (base de datos y usuario).

---

## 1. Descarga del instalador

1. Desde la VM, abrir Microsoft Edge y entrar a la página oficial de descargas de SQL Server (`microsoft.com/es-es/sql-server/sql-server-downloads`).
2. La página ofrece varias ediciones: SQL Server 2025 local (pago), SQL Server en Azure, **Developer** (gratuita, para desarrollo y pruebas fuera de producción) y **Express** (gratuita, con límites de tamaño).
3. Se eligió **Desarrollador de SQL Server 2025 → Standard Developer**.

**Por qué Standard Developer:** es gratuita, no caduca y tiene las mismas funciones que la edición Standard. Su licencia permite solo desarrollo y pruebas, que es justo el uso de este laboratorio. Incluye además funciones de auditoría que se usarán en la Fase 4.

<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/01-sql-server/1.png" width="600"> </p>

---

## 2. Descarga de los archivos de instalación (instalación Custom)

Al ejecutar el instalador pequeño aparecen tres opciones:

|Opción|Qué hace|
|---|---|
|Basic|Instala el motor con la configuración predeterminada, sin pasar por el asistente completo.|
|Custom|Recorre el asistente de instalación completo para elegir qué instalar y cómo configurarlo. Es más detallado y tarda más que Basic.|
|Download Media|Solo descarga los archivos de instalación para instalarlos más tarde, en este u otro equipo.|

Se eligió **Custom**. Con esta opción el instalador descarga primero los archivos de instalación y después abre el asistente completo, donde se decide la edición, las características, las cuentas de servicio y el modo de autenticación. Eso es necesario en este laboratorio, porque Basic aplica la configuración predeterminada y no permite elegir el modo de autenticación mixto que se necesita (sección 3.4). Download Media no se usó, porque solo descarga los archivos y no inicia la instalación.

En la pantalla siguiente (_Specify SQL Server media download target location_) se configuró:

- **Idioma:** English.
- **Ubicación de los archivos:** `C:\SQL2025`.
- Requisitos que mostró el instalador: 8752 MB libres como mínimo y 1311 MB de descarga.

Se pulsó **Install** para descargar los archivos. Al terminar la descarga, el instalador abre por sí solo el asistente de instalación completo (sección 3).

<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/01-sql-server/2.png" width="600"> </p>

<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/01-sql-server/3.png" width="600"> </p>

---

## 3. Instalación del motor de base de datos

Al terminar la descarga se abre el **SQL Server Installation Center**. Desde la sección **Installation** se inicia una instalación nueva independiente (_New SQL Server stand-alone installation_).

<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/01-sql-server/4.png" width="600"> </p>

### 3.1 Edición

Se seleccionó **Specify a free edition → Standard Developer**.

<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/01-sql-server/5.png" width="600"> </p>

### 3.2 Selección de características (Feature Selection)

Se marcó únicamente **Database Engine Services**. No se instaló nada más (Analysis Services, Integration Services, replicación, PolyBase, etc.), porque el laboratorio solo necesita el motor relacional.

Rutas que se dejaron como vienen por defecto:

- Instance root directory: `C:\Program Files\Microsoft SQL Server\`
- Shared feature directory: `C:\Program Files\Microsoft SQL Server\`
- Shared feature directory (x86): `C:\Program Files (x86)\Microsoft SQL Server\`

El instalador indicó que descargaría el prerrequisito _Microsoft Visual C++ 2017 Redistributable_.

<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/01-sql-server/6.png" width="600"> </p>

### 3.3 Configuración del servidor (Server Configuration)

Cuentas de servicio y tipo de inicio, tal como quedaron:

|Servicio|Cuenta|Tipo de inicio|
|---|---|---|
|SQL Server Agent|`NT Service\SQLSERVERAGENT`|Manual|
|SQL Server Database Engine|`NT Service\MSSQLSERVER`|Automático|
|SQL Server Browser|`NT AUTHORITY\LOCAL SERVICE`|Disabled|

El motor arranca automáticamente con Windows. No se activó el privilegio _Perform Volume Maintenance Tasks_.

<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/01-sql-server/7.png" width="600"> </p>

### 3.4 Configuración del motor (Database Engine Configuration)

Esta pantalla contiene las dos decisiones de seguridad más importantes de la instalación:

- **Authentication Mode: Mixed Mode (SQL Server authentication and Windows authentication).** La aplicación web se conectará con un usuario de SQL Server (`webuser`) y no con una cuenta de Windows. Eso exige el modo mixto. En este modo el instalador obliga a definir una contraseña para la cuenta administradora `sa`.
- **SQL Server administrators:** (add current user) se agregó la cuenta `WIN-5OCEJPK16SB\Administrador`, que tendrá acceso sin restricciones al motor. Con ella se trabaja desde SSMS.

> La contraseña de `sa` no se documenta en este repositorio.

<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/01-sql-server/8.png" width="600"> </p>

### 3.5 Resumen previo y resultado

Antes de instalar, el resumen confirmó:

- Edición: Standard Developer. Acción: Install.
- Característica: Database Engine Services.
- **Instance Name / Instance ID: `MSSQLSERVER`** (instancia predeterminada, sin nombre).
- Directorio de la instancia: `C:\Program Files\Microsoft SQL Server\`.
- Actualizaciones de producto activadas (`Update Enabled: True`).

La instalación terminó con el mensaje _"Your SQL Server 2025 installation completed successfully with product updates"_. Los componentes aparecen como **Succeeded**: Database Engine Services, SQL Browser, SQL Writer y Setup Support Files. El registro queda en `C:\Program Files\Microsoft SQL Server\170\Setup Bootstrap\Log\`.

<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/01-sql-server/9.png" width="600"> </p>

> **Dato que importa más adelante:** al ser una instancia predeterminada, el servidor se llama simplemente `localhost` (o `.`), no `localhost\SQLEXPRESS`. Esto condiciona la cadena de conexión de la aplicación web en la Fase 2.

---

## 4. Instalación de SQL Server Management Studio (SSMS)

SSMS no viene con el motor, se instala aparte. Se usó el instalador de **SQL Server Management Studio 22 (versión 22.10.2)**, que se ejecuta sobre el Visual Studio Installer:

- Carga de trabajo: **SSMS** (componentes principales).
- Ubicación: `C:\Program Files\Microsoft SQL Server Management Studio 22\Release`.
- Espacio necesario: 3.83 GB.
- Modo: _Instalar durante la descarga_.

No se marcaron las cargas opcionales (Asistencia de IA, Inteligencia empresarial, Híbrido y migración, Herramientas de código).

<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/01-sql-server/10.png" width="600"> </p>

### Primera conexión

Al abrir SSMS se conectó a `localhost` con **autenticación de Windows**. El Explorador de objetos muestra `localhost (17.0.1000.7 de SQL Server - WIN-5OCEJPK16SB\Administrador)`. La versión `17.0.1000.7` corresponde a SQL Server 2025.

<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/01-sql-server/11.png" width="600"> </p>

---

## 5. Red: TCP/IP y firewall

### 5.1 Habilitar TCP/IP

En **SQL Server Configuration Manager → Configuración de red de SQL Server → Protocols for MSSQLSERVER** el estado de los protocolos es:

|Protocolo|Estado|
|---|---|
|Shared Memory|Enabled|
|Named Pipes|Disabled|
|**TCP/IP**|**Enabled**|

En las propiedades de TCP/IP: `Enabled = Yes`, `Keep Alive = 30000` y `Listen All = Yes`.

<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/01-sql-server/12.png" width="600"> </p>

### 5.2 Regla de firewall para el puerto 1433

En **Firewall de Windows Defender con seguridad avanzada → Reglas de entrada → Nueva regla** se creó una regla de tipo puerto:

- Protocolo: **TCP**.
- Puertos locales específicos: **1433** (puerto predeterminado de SQL Server).
- Perfil: todos. Nombre: `SQL SERVER 1433`.

La regla aparece al inicio de la lista de reglas de entrada, habilitada (columna _Habilitada = Sí_).

<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/01-sql-server/13.png" width="600"> </p>

<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/01-sql-server/14.png" width="600"> </p>

---

## 6. Base de datos `LabSQLi`

Se creó la base de datos del laboratorio con el nombre `LabSQLi`. En el Explorador de objetos aparece como `LabSQLI`: SQL Server no distingue mayúsculas de minúsculas en los nombres con la configuración regional predeterminada, así que ambas escrituras apuntan a la misma base.
```sql
CREATE DATABASE LabsSQLI;
```

---

## 7. Tabla `Usuarios` y datos de prueba

Desde una consulta nueva en SSMS, con `LabSQLi` seleccionada como base activa, se ejecutó:

```sql
USE LabSQLi;
CREATE TABLE Usuarios (
id INT PRIMARY KEY IDENTITY,
usuario VARCHAR(50),
clave VARCHAR(50),
rol VARCHAR(20)
);

INSERT INTO Usuarios (usuario,clave,rol) VALUES
('admin','Admin1234!','administrador'),
('jperez','Clave456!','usuario');
```

### Explicación línea por línea

| Línea                         | Qué hace                                                                                  |
| ----------------------------- | ----------------------------------------------------------------------------------------- |
| `USE LabSQLi;`                | Cambia el contexto a la base `LabSQLi`. Sin esto la tabla se crearía en la base `master`. |
| `CREATE TABLE Usuarios (...)` | Crea la tabla `Usuarios`.                                                                 |
| `id INT PRIMARY KEY IDENTITY` | Identificador numérico único, que SQL Server genera solo (1, 2, 3...).                    |
| `usuario VARCHAR(50)`         | Nombre de usuario, hasta 50 caracteres.                                                   |
| `clave VARCHAR(50)`           | Contraseña, hasta 50 caracteres.                                                          |
| `rol VARCHAR(20)`             | Rol del usuario (`administrador` o `usuario`).                                            |
| `INSERT INTO ... VALUES`      | Inserta dos filas de prueba.                                                              |

SSMS respondió **`(2 filas afectadas)`** y el estado _Consulta ejecutada correctamente_. En el Explorador de objetos la tabla `dbo.Usuarios` muestra las columnas `id (PK, int, No NULL)`, `usuario (varchar(50), NULL)`, `clave (varchar(50), NULL)` y `rol (varchar(20), NULL)`.

<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/01-sql-server/15.png" width="600"> </p>

### Decisión de diseño deliberada

La columna `clave` guarda las contraseñas **en texto plano** (sin hash). Es intencional: forma parte del escenario vulnerable que se ataca en la Fase 3. En un sistema real las contraseñas se almacenan con un hash con sal (por ejemplo bcrypt, Argon2 o PBKDF2), nunca en claro.

### Credenciales de prueba

|usuario|clave|rol|
|---|---|---|
|`admin`|`Admin1234!`|administrador|
|`jperez`|`Clave456!`|usuario|

Son credenciales ficticias de laboratorio.

---

## 8. Inicio de sesión y usuario `webuser`

La aplicación web no debe conectarse con la cuenta de administrador. Se creó una cuenta propia para ella:

```sql
CREATE LOGIN webuser WITH PASSWORD = 'WebPass123!';
GO
USE LabSQLi;
GO
CREATE USER webuser FOR LOGIN webuser;
ALTER ROLE db_owner ADD MEMBER webuser;
```

### Explicación línea por línea

|Línea|Qué hace|
|---|---|
|`CREATE LOGIN webuser WITH PASSWORD = ...`|Crea el **inicio de sesión** a nivel de servidor (la identidad que puede conectarse a la instancia).|
|`GO`|Separa lotes. El cambio de base de datos con `USE` debe estar en un lote aparte de la creación del login.|
|`USE LabSQLi;`|Cambia a la base del laboratorio.|
|`CREATE USER webuser FOR LOGIN webuser;`|Crea el **usuario** dentro de la base de datos y lo enlaza con el login. Login y usuario son dos objetos distintos.|
|`ALTER ROLE db_owner ADD MEMBER webuser;`|Agrega el usuario al rol `db_owner`, es decir, control total sobre `LabSQLi`.|

<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/01-sql-server/16.png" width="600"> </p>

### Decisión de diseño deliberada

Se asignó `db_owner` a propósito: es una configuración **excesivamente permisiva**, típica de una aplicación mal configurada. Con ese rol, una inyección SQL exitosa no solo puede leer la tabla `Usuarios`, también puede modificar o eliminar datos y objetos de toda la base. La corrección (retirar `db_owner` y conceder solo `SELECT`) se aplica en la **Fase 5** con el script `sql/03_minimo_privilegio.sql`.

---

## 9. Verificación del estado final

|Elemento|Valor|
|---|---|
|Versión del motor|SQL Server 2025, 17.0.1000.7|
|Edición|Standard Developer|
|Instancia|`MSSQLSERVER` (predeterminada) → se accede como `localhost`|
|Autenticación|Modo mixto|
|Protocolos|TCP/IP y Shared Memory habilitados; Named Pipes deshabilitado|
|Puerto|1433/TCP con regla de entrada en el firewall|
|Base de datos|`LabSQLi`|
|Tabla|`dbo.Usuarios` (2 filas)|
|Login / usuario de aplicación|`webuser` (rol `db_owner`, intencional)|

## 10. Nota para la siguiente fase

Al conectar la aplicación ASP clásica con este servidor aparecieron tres problemas de conexión (proveedor obsoleto, proveedor no instalado y certificado SSL no confiable). Todos se resuelven del lado de IIS y de la cadena de conexión, y quedan documentados en `02-webapp-login.md`.

Scripts de esta fase: `sql/01_base_de_datos.sql`.
