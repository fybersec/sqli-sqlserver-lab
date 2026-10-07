# Fase 2: Aplicación web de login (IIS + ASP clásico)

Esta fase construye la aplicación web que se atacará en la Fase 3. Al terminarla se tiene:

- IIS 10 instalado en la VM Windows Server, con soporte para ASP clásico.
- Un formulario de login basado en una plantilla de terceros, publicado en `http://localhost/lab/`.
- Un archivo `login.asp` que recibe usuario y contraseña, consulta la base `LabSQLi` (Fase 1) y responde si el acceso es válido.
- Los errores detallados de ASP e IIS visibles en el navegador, incluso desde una máquina remota, necesarios para diagnosticar la conexión y para que la explotación de la Fase 3 funcione desde Kali.

> **Requisito previo:** haber completado la Fase 1 (SQL Server 2025 instancia `MSSQLSERVER`, base `LabSQLi`, tabla `Usuarios` y login `webuser`).
> 
> **Código fuente:** el contenido completo de `index.html`, `style.css` y `login.asp` está en la carpeta `webapp/`. Este documento no repite el código de `login.asp`: explica qué hace cada bloque y qué decisiones de configuración requiere para funcionar.

---

## Resumen de pasos

|#|Paso|Resultado|
|---|---|---|
|1|Instalar el rol Servidor web (IIS) con ASP|IIS funcionando|
|2|Verificar IIS en el navegador|Página de bienvenida en `localhost`|
|3|Descargar la plantilla de login|`index.html` y `style.css`|
|4|Publicar la plantilla en `C:\inetpub\wwwroot\lab`|Formulario visible en `localhost/lab/`|
|5|Adaptar `index.html`|Sin login social, `action="login.asp"`|
|6|Activar los errores detallados de ASP|Mensajes de error reales en el navegador (local)|
|7|Activar los errores detallados de IIS en la carpeta `lab`|Mensajes de error reales también desde peticiones remotas (Kali)|
|8|Instalar el driver OLE DB y ajustar el pool de IIS|Proveedor disponible para ASP|
|9|Crear `login.asp`|Login conectado a SQL Server|
|10|Probar el flujo completo|"Acceso concedido" / "Usuario o clave incorrectos"|

---

## 1. Instalación de IIS con ASP

1. Abrir **Administrador del servidor** → **Administrar** → **Agregar roles y características**.
2. En _Roles de servidor_ marcar **Servidor web (IIS)**. El asistente pide agregar las herramientas de administración: aceptar.

<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/02-webapp-login/3.png" width="600"> </p>


3. En _Servicios de rol_ se dejaron marcados los siguientes elementos (el resto, sin marcar):

|Categoría|Servicio de rol|Para qué se usa|
|---|---|---|
|Rendimiento|Compresión de contenido estático|Comprime archivos estáticos (HTML, CSS).|
|Seguridad|**Filtrado de solicitudes**|Es la función de IIS que se configurará en la Fase 5 para bloquear patrones de ataque.|
|Desarrollo de aplicaciones|**ASP**|Permite ejecutar archivos `.asp` (ASP clásico, con VBScript).|
|Desarrollo de aplicaciones|**Extensiones ISAPI**|Dependencia de ASP: el asistente la marca automáticamente al elegir ASP.|
|Herramientas de administración|Consola de administración de IIS|Interfaz gráfica para administrar IIS.|

Además se instalaron los servicios predeterminados del rol: Documento predeterminado, Examen de directorios, Errores HTTP, Contenido estático y Registro HTTP.

<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/02-webapp-login/4.png" width="600"> </p>

4. Pulsar **Instalar**. La pantalla de progreso lista todos los componentes que se están instalando.

<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/02-webapp-login/5.png" width="600"> </p>

5. Al terminar aparece _"Instalación correcta en WIN-5OCEJPK16SB"_. Pulsar **Cerrar**. En el panel izquierdo del Administrador del servidor aparece ahora la entrada **IIS**.

<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/02-webapp-login/6.png" width="600"> </p>

6. Abrir el **Administrador de Internet Information Services (IIS)** (menú Inicio o _Herramientas_ del Administrador del servidor). La página de inicio muestra "Internet Information Services 10" y la conexión `localhost`.

<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/02-webapp-login/7.png" width="600"> </p>


7. En el árbol de conexiones expandir **Sitios → Default Web Site**. En el panel central aparece el ícono **ASP**, que confirma que el soporte quedó instalado.

---

## 2. Verificación de IIS

Abrir Microsoft Edge en la misma VM y entrar a `http://localhost`. Debe aparecer la página de bienvenida de _Internet Information Services_.

<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/02-webapp-login/8.png" width="600"> </p>
Si no aparece, revisar que el servicio _Servicio de publicación World Wide Web_ esté en ejecución y que el sitio _Default Web Site_ esté iniciado.

---

## 3. Plantilla del formulario de login

Para no dedicar tiempo al diseño visual (que no es el objetivo del laboratorio) se usó una plantilla gratuita de GitHub:

- **Repositorio:** `https://github.com/LucasDaniel0/login-form`
- **Autor:** Lucas Daniel (`LucasDaniel0`)
- **Licencia:** MIT
- **Archivos usados:** `index.html` y `style.css`

Se descargaron únicamente esos dos archivos (subrayados en la captura).

<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/02-webapp-login/9.png" width="600"> </p>

### Atribución (importante para el repositorio)

La licencia MIT permite reutilizar el código, pero exige conservar el aviso de copyright y el texto de la licencia en las copias. Por eso, en el repositorio del laboratorio:

- `style.css` se conserva **sin cambios**.
- `index.html` se conserva con las modificaciones descritas en la sección 5.
- Se debe incluir una nota de créditos con el autor, el enlace al repositorio original y el texto de la licencia MIT del autor (por ejemplo en `webapp/README.md` o en un archivo `webapp/LICENSE-login-form`).

---

## 4. Publicación de la plantilla en IIS

1. Abrir el Explorador de archivos y crear la carpeta **`C:\inetpub\wwwroot\lab`**. Esta ruta es la raíz física del sitio `Default Web Site`, por lo que todo lo que se guarde dentro es accesible como `http://localhost/lab/...`.
2. Copiar `index.html` y `style.css` dentro de `lab`.
3. Abrir `http://localhost/lab/` en el navegador. IIS sirve `index.html` automáticamente porque es un _documento predeterminado_.

La plantilla original muestra el formulario con el campo _E-mail_, el campo _Password_, el botón _Continue_ y los botones de _Sign in with Facebook_ y _Sign in with GitHub_.

<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/02-webapp-login/10.png" width="600"> </p>
<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/02-webapp-login/11.png" width="600"> </p>
<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/02-webapp-login/12.png" width="600"> </p>
<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/02-webapp-login/13.png" width="600"> </p>

### Recomendaciones para evitar errores

- **Mostrar las extensiones de archivo.** En el Explorador: pestaña _Vista_ → marcar _Extensiones de nombre de archivo_. Sin esto, un archivo guardado como `login.asp.txt` se ve como `login`, y IIS no lo ejecuta como ASP.
- **Guardar con permisos de administrador.** Abrir el Bloc de notas con _Ejecutar como administrador_, porque `C:\inetpub` está protegido.
- **Guardar siempre con tipo "Todos los archivos"** y escribiendo el nombre completo con extensión (`login.asp`), para que el Bloc de notas no agregue `.txt`.

---

## 5. Adaptación de `index.html`

Se abrió `index.html` con el Bloc de notas (como administrador). El archivo original tiene tres elementos que no sirven para el laboratorio o que impiden que funcione.

### Cambios realizados

|#|Original|Modificado|Motivo|
|---|---|---|---|
|1|`<form action="#" method="POST">`|`<form action="login.asp" method="POST">`|Con `#` el formulario no envía los datos a ningún archivo. Con `login.asp` envía por POST al script que consulta la base.|
|2|`<input type="text" name="email" id="email" placeholder="E-mail" />`|`<input type="text" name="User" id="user" placeholder="User" />`|El campo ya no es un correo, sino un nombre de usuario (la tabla `Usuarios` tiene la columna `usuario`).|
|3|Bloque `<footer>` con los botones de Facebook y GitHub y el texto _Or Connect With Social Media_|Eliminado|El laboratorio solo usa autenticación con usuario y contraseña.|
|4|`<script src="https://kit.fontawesome.com/..." crossorigin="anonymous"></script>`|Eliminado por completo (etiqueta de apertura y de cierre)|Cargaba los íconos de Font Awesome, que solo usaba el footer social. Además es una dependencia externa innecesaria en una red aislada.|


> **Corrección importante:** al editar, es fácil borrar solo la dirección `src="..."` y dejar la etiqueta vacía (`<script></script>`). No rompe nada, pero es código muerto: se debe borrar la etiqueta completa.

### Regla clave: el atributo `name`

El valor del atributo `name` de cada campo es el nombre con el que el servidor recibe el dato. El script `login.asp` lee `Request.Form("User")` y `Request.Form("password")`, así que:

- El `name` del campo de usuario en el HTML **debe coincidir** con el nombre que lee `login.asp`.
- Si se cambia uno, hay que cambiar el otro.
- El `placeholder` y el `id` son solo visuales/de estilo y no afectan al envío.

### Resultado

Al recargar `http://localhost/lab/` con Ctrl+F5 el formulario aparece con los campos _User_ y _Password_ y el botón _Continue_, sin login social.

---

## 6. Activar los errores detallados de ASP

Por defecto, IIS oculta los errores de ASP y muestra un mensaje genérico (_"An error occurred on the server when processing the URL..."_). Para diagnosticar la conexión con SQL Server hay que activar los errores reales.

1. En el **Administrador de IIS** seleccionar **Default Web Site** y abrir el ícono **ASP**.
2. Expandir **Propiedades de depuración**.
3. Cambiar **Enviar errores al explorador** de `False` a **`True`**.
4. En el panel derecho, pulsar **Aplicar**. Debe aparecer el aviso _"Los cambios se guardaron correctamente"_.

<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/02-webapp-login/14.png" width="600"> </p>

Con esto el navegador muestra el tipo de error, su código (por ejemplo `80004005`), la descripción y el número de línea del script.

> **Nota de seguridad:** esta opción revela información interna (proveedor, nombre de servidor, estructura de la consulta). Se activa **a propósito** en el laboratorio, porque facilita el diagnóstico y porque forma parte del escenario vulnerable. En un entorno real debe permanecer en `False`. Se restablece a `False` en la Fase 5.

> **Importante — esto solo resuelve la mitad del problema.** El paso de esta sección hace que _ASP_ genere el mensaje detallado, pero es _IIS_ quien decide a quién se lo muestra. Con la configuración predeterminada de IIS, ese detalle solo llega a peticiones que el servidor considera "locales" (el navegador dentro de la misma VM). Una petición que llega por red, como la del ataque de la Fase 3 lanzado desde Kali, se trata como "remota" y recibe en su lugar la página genérica de error 500, sin ningún detalle. La sección 7 cubre el ajuste que falta para que el error detallado llegue también por red.

---

## 7. Errores detallados de IIS para peticiones remotas

Este paso es indispensable para que la Fase 3 funcione: sin él, el bypass simple (`' OR 1=1-- -`) sí funciona desde Kali porque no genera ningún error, pero los cuatro payloads de inyección basada en errores dependen por completo de que el mensaje detallado llegue hasta el atacante, y fallan con un 500 genérico si se lanzan desde una máquina remota.

### La causa

IIS tiene una característica, independiente de la de ASP (sección 6), llamada **Páginas de errores**, con tres modos posibles:

- Páginas de error personalizadas
- **Errores detallados para solicitudes locales y páginas de error personalizadas para solicitudes remotas** ← valor predeterminado
- Errores detallados

Con el valor predeterminado, IIS distingue si la petición viene de `localhost` (local) o de otra IP de la red (remota), y solo entrega el detalle completo en el primer caso.

### La corrección

1. En el **Administrador de IIS**, en el árbol de conexiones, bajar hasta la carpeta de la aplicación: **Sitios → Default Web Site → lab**.
2. En el panel central, doble clic en **Páginas de errores**.
3. En el panel derecho (Acciones), clic en **Modificar configuración de característica...**.
4. Seleccionar el radio button **Errores detallados**.
5. Clic en **Aceptar**.

<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/02-webapp-login/15.png" width="600"> </p>

> **Alcance del cambio:** el ajuste se aplicó estando parado en la carpeta `lab`, no en `Default Web Site`. Por eso queda escrito en el `web.config` de esa subcarpeta (`Default Web Site/lab`) y no afecta al resto del sitio ni al servidor completo. Esto mantiene el cambio acotado solo a la aplicación vulnerable y es más fácil de revertir en la Fase 5.

### Verificación

Repetir uno de los payloads de inyección basada en errores (sección 2 de `03-ataque-sqli.md`) desde Kali, apuntando a `http://<IP-del-servidor>/lab/login.asp`. El mensaje de error detallado de SQL Server debe llegar completo en la respuesta, igual que ocurre en el navegador local.

**Confirmado: con este cambio aplicado, los payloads avanzados funcionan correctamente desde Kali.**

---

## 8. Driver OLE DB y grupo de aplicaciones

`login.asp` se conecta a SQL Server mediante **ADODB** con un _proveedor OLE DB_. Para SQL Server 2025 hace falta un proveedor moderno.

### 8.1 Instalar el driver

Descargar e instalar **Microsoft OLE DB Driver 19 for SQL Server** desde la página oficial de Microsoft. En este laboratorio se instaló la versión **x86 (32 bits)**, porque el grupo de aplicaciones está configurado en modo de 32 bits (ver 8.2). El proveedor se llama `MSOLEDBSQL19`.

### 8.2 Habilitar aplicaciones de 32 bits en el grupo de aplicaciones

1. En el Administrador de IIS, panel izquierdo, abrir **Grupos de aplicaciones**.
2. Seleccionar **DefaultAppPool**.
3. En el panel derecho pulsar **Configuración avanzada...**.
4. En el grupo _(General)_, cambiar **Habilitar aplicaciones de 32 bits** a **`True`** y pulsar **Aceptar**.
5. Con el grupo seleccionado, pulsar **Reciclar...** en el panel derecho para que el cambio surta efecto.

<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/02-webapp-login/16.png" width="600"> </p>

> **Configuración verificada:** pool en 32 bits + driver x86. Es la combinación con la que funcionó el laboratorio.
> 
> **Alternativa (no verificada en este laboratorio):** dejar el pool en 64 bits (`Habilitar aplicaciones de 32 bits = False`, el valor predeterminado) e instalar el driver **x64**. En teoría es equivalente y evita el modo de compatibilidad, pero conviene comprobarla antes de documentarla como válida. La regla general es que **la arquitectura del driver debe coincidir con la del grupo de aplicaciones**.

---

## 9. El archivo `login.asp`

Se crea con el Bloc de notas (como administrador) en `C:\inetpub\wwwroot\lab\login.asp`, guardado como "Todos los archivos". El código completo está en `webapp/login.asp`.

### Qué hace el script, bloque por bloque

| Bloque                              | Qué hace                                                                                 | Detalle                                                                                                                                              |
| ----------------------------------- | ---------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1. Delimitadores `<% ... %>`        | Marcan el código que se ejecuta en el servidor.                                          | El navegador nunca ve este código, solo el resultado.                                                                                                |
| 2. Declaración de variables (`Dim`) | Reserva las variables que se usarán.                                                     | Conexión, resultado, consulta y los dos datos del formulario.                                                                                        |
| 3. Lectura del formulario           | Obtiene lo que el usuario escribió.                                                      | `Request.Form("User")` y `Request.Form("password")` leen los campos enviados por POST.                                                               |
| 4. Creación del objeto de conexión  | Crea la conexión a la base.                                                              | `Set conn = Server.CreateObject("ADODB.Connection")`. Sin esta línea, el script falla con _"Se requiere un objeto"_.                                 |
| 5. Apertura de la conexión          | Se conecta a SQL Server con `conn.Open` y la cadena de conexión.                         | Ver el desglose de la cadena abajo.                                                                                                                  |
| 6. Construcción de la consulta      | Arma el texto SQL **concatenando** directamente los datos del usuario.                   | Es la vulnerabilidad intencional del laboratorio.                                                                                                    |
| 7. Ejecución                        | `conn.Execute(sql)` envía la consulta a SQL Server y devuelve un conjunto de resultados. |                                                                                                                                                      |
| 8. Decisión                         | Si el resultado tiene al menos una fila, el acceso se concede.                           | `rs.EOF` es `True` cuando no hay filas. Con filas, muestra "Acceso concedido. Bienvenido" más el usuario. Sin filas, "Usuario o clave incorrectos.". |
| 9. Cierre                           | Cierra el resultado y la conexión.                                                       | `rs.Close` y `conn.Close`.                                                                                                                           |

### La cadena de conexión

La cadena es el punto donde se concentraron los problemas de esta fase. Sus partes:

|Parámetro|Valor|Significado|
|---|---|---|
|`Provider`|`MSOLEDBSQL19`|Microsoft OLE DB Driver 19 for SQL Server.|
|`Server`|`localhost`|La instancia predeterminada (`MSSQLSERVER`), sin nombre de instancia.|
|`Database`|`LabSQLi`|La base de datos del laboratorio.|
|`UID` / `PWD`|`webuser` / contraseña de `webuser`|Autenticación de SQL Server (Fase 1).|
|`Use Encryption for Data`|`True`|Mantiene la conexión cifrada. El driver 19 cifra por defecto.|
|`Trust Server Certificate`|`True`|Acepta el certificado autofirmado que SQL Server genera al instalarse.|

### Cómo queda la consulta que se envía

Con las credenciales de prueba `admin` / `Admin1234!`, el texto SQL resultante es:

```sql
SELECT * FROM Usuarios WHERE usuario='admin' AND clave='Admin1234!'
```

El script no valida ni escapa lo que escribe el usuario: lo que se teclea se pega tal cual dentro de las comillas. En la Fase 3 se explota esto, y en la Fase 5 se corrige con consultas parametrizadas.

---

## 10. Pruebas

1. Abrir `http://localhost/lab/` y pulsar **Ctrl+F5** para evitar la caché.
2. Escribir `admin` en _User_ y `Admin1234!` en _Password_ y pulsar **Continue**.
3. El navegador va a `http://localhost/lab/login.asp` y debe mostrar: **"Acceso concedido. Bienvenido admin"**.
4. Repetir con una contraseña incorrecta: debe mostrar **"Usuario o clave incorrectos."**.

> **Importante:** probar siempre enviando el formulario desde `index.html`. Abrir `login.asp` directamente en la barra de direcciones lo ejecuta sin datos y no sirve como prueba.

### Truco de depuración

Para confirmar que el servidor ejecuta la versión guardada del script, se puede agregar temporalmente una línea que imprima un texto (por ejemplo "version nueva") al inicio del bloque ASP. Si el texto no aparece al enviar el formulario, el archivo no se guardó o se está sirviendo otra copia. **Hay que borrar esa línea al terminar.**

---

## 11. Errores encontrados y cómo se resolvieron

Esta tabla resume el diagnóstico real del laboratorio, en el orden en que aparecieron. Sirve como guía de resolución de problemas.

|#|Mensaje en el navegador|Código|Causa|Solución|
|---|---|---|---|---|
|1|Error genérico de IIS (sin detalle)|500|IIS oculta los errores de ASP.|Activar _Enviar errores al explorador_ (sección 6).|
|2|_Se requiere un objeto: ''_|`800a01a8` (VBScript)|Faltaba crear el objeto de conexión: `conn.Open` se ejecutaba sobre una variable vacía.|Agregar la línea `Set conn = Server.CreateObject("ADODB.Connection")` antes de `conn.Open`.|
|3|_[DBNETLIB] No existe el servidor SQL Server o se ha denegado el acceso al mismo_|`80004005`|Se usaba `SQLOLEDB`, un proveedor antiguo (basado en DBNETLIB) que no logra conectar con SQL Server 2025. El error no se debía al nombre del servidor.|Cambiar a un proveedor moderno (puntos 8.1 y 8.2).|
|4|_No se encontró el proveedor especificado. Es posible que no esté instalado correctamente._|`800a0e7a` (ADODB)|Se probó `SQLNCLI11`, que no estaba registrado como proveedor OLE DB en el equipo.|Instalar Microsoft OLE DB Driver 19 (sección 8.1).|
|5|_SSL Provider: La cadena de certificación fue emitida por una entidad en la que no se confía_|`80004005`|El driver 19 cifra por defecto y SQL Server usa un certificado autofirmado.|Agregar `Trust Server Certificate=True` a la cadena (sección 9).|
|6|Error genérico 500 de IIS, pero **solo al atacar desde Kali** (desde el navegador local sí se veía el detalle)|500|_Enviar errores al explorador_ (ASP) estaba en `True`, pero la característica _Páginas de errores_ de IIS seguía en su valor predeterminado, que solo entrega el detalle a peticiones locales.|Cambiar _Páginas de errores_ a **Errores detallados** en la carpeta `lab` (sección 7). Verificado: los payloads avanzados funcionan desde Kali tras el cambio.|
|7|_Acceso concedido. Bienvenido admin_|n/a|Funciona.|n/a|

### Aclaraciones sobre pruebas que no funcionaron

- **`Data Source=localhost\SQLEXPRESS`:** se probó por una suposición incorrecta. La instalación de la Fase 1 es la instancia predeterminada (`MSSQLSERVER`), no SQL Server Express, así que ese nombre de instancia no existe. Con instancia predeterminada se usa solo `localhost`.
- **`Encrypt=no;TrustServerCertificate=yes`:** al probar estas palabras clave, el error de certificado se repitió. En ese intento se cambió la cadena y a la vez no se comprobó que el archivo se hubiera guardado, así que no se pudo aislar si el fallo fue de las palabras clave o de un guardado incorrecto. La cadena verificada es la de la sección 9, con `Use Encryption for Data` y `Trust Server Certificate`.
- **Habilitar 32 bits:** se activó al inicio como medida para el proveedor antiguo `SQLOLEDB`. No era la causa del problema original. Se mantuvo porque con el driver x86 funciona.

---

## 12. Decisiones deliberadas de diseño (se corrigen en la Fase 5)

|Decisión|Por qué se hace así|Se corrige en|
|---|---|---|
|Consulta SQL construida por concatenación|Es la vulnerabilidad de inyección SQL que se demuestra en la Fase 3.|Fase 5: consulta parametrizada (`login_seguro.asp`).|
|Contraseña de `webuser` escrita en la cadena de conexión|Simplifica el laboratorio. En un sistema real las credenciales no van en el código.|Mención en Fase 5.|
|`webuser` con rol `db_owner`|Maximiza el impacto de una inyección.|Fase 5: mínimo privilegio.|
|Errores detallados de ASP al navegador|Facilitan el diagnóstico y la explotación.|Fase 5: volver _Enviar errores al explorador_ a `False`.|
|Errores detallados de IIS para peticiones remotas (carpeta `lab`)|Sin este ajuste, los payloads de inyección basada en errores no funcionan contra un atacante remoto real, que es el escenario que el laboratorio simula.|Fase 5: devolver _Páginas de errores_ a su valor predeterminado ("Errores detallados para solicitudes locales y páginas de error personalizadas para solicitudes remotas"), que es el comportamiento seguro de producción.|

---

## 13. Estado final de la fase

|Elemento|Valor|
|---|---|
|Servidor web|IIS 10 en Windows Server|
|Servicios de rol clave|ASP, Extensiones ISAPI, Filtrado de solicitudes|
|Sitio|`Default Web Site` en el puerto 80|
|Carpeta de la aplicación|`C:\inetpub\wwwroot\lab`|
|Archivos|`index.html`, `style.css`, `login.asp`|
|Proveedor de datos|`MSOLEDBSQL19` (driver x86)|
|Grupo de aplicaciones|`DefaultAppPool` con aplicaciones de 32 bits habilitadas|
|Errores detallados|ASP = `True` (Default Web Site) · IIS "Errores detallados" = activado (carpeta `lab`, verificado desde Kali)|
|URL de prueba|`http://localhost/lab/`|
|Credenciales de prueba|`admin` / `Admin1234!`|

Siguiente fase: `03-ataque-sqli.md`.
