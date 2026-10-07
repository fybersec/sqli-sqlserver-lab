# Fase 6: Verificación

Esta fase cierra el laboratorio con la prueba que faltaba: repetir, contra `login_seguro.asp`, exactamente los mismos payloads que funcionaron en la Fase 3 contra `login.asp`, y confirmar que ninguno sigue siendo funcional. No se explica aquí por qué cambia el comportamiento — eso ya quedó documentado en `05-proteccion.md` (sección 1) y en el diagrama de comparación. Esta fase es solo evidencia de resultado: antes fallaba la aplicación, ahora falla el ataque.

> **Requisito previo:** `login_seguro.asp` copiado en `C:\inetpub\wwwroot\lab\`, con la contraseña real de `webuser` ya puesta en la cadena de conexión (Fase 5).
> 
> **Importante:** todas las pruebas de esta fase se hacen contra `http://<IP-del-servidor>/lab/login_seguro.asp`, no contra `login.asp`. Confundir el archivo invalida la prueba.

---

## Resumen de pasos

|#|Prueba|Resultado esperado|
|---|---|---|
|1|Login legítimo (`admin` / `Admin1234!`)|Acceso concedido — confirma que la corrección no rompió el uso normal|
|2|Bypass simple (`' OR 1=1-- -`)|Usuario o clave incorrectos|
|3|Payload de bases de datos|Usuario o clave incorrectos, sin error|
|4|Payload de tablas|Usuario o clave incorrectos, sin error|
|5|Payload de columnas|Usuario o clave incorrectos, sin error|
|6|Payload de extracción de credenciales|Usuario o clave incorrectos, sin error|

---

## 1. Prueba de control: el login legítimo sigue funcionando

Antes de probar que el ataque falla, hay que confirmar que la corrección no rompió el caso normal — si `login_seguro.asp` rechazara también las credenciales correctas, la "prueba" de los payloads no demostraría nada.

1. Abrir `http://localhost/lab/` (o la URL correspondiente) y pulsar **Ctrl+F5**.
2. Confirmar que el `action` del formulario apunta a `login_seguro.asp` para esta prueba (o enviar la petición directamente a esa ruta).
3. Escribir `admin` / `Admin1234!` y enviar.
4. Debe mostrar: **"Acceso concedido. Bienvenido admin"**.

<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/06-verificacion/1.png" width="600"> </p>
<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/06-verificacion/2.png" width="600"> </p>

---

## 2. Bypass simple

Payload (campo _User_, dejando _Password_ vacío o con cualquier valor):

```
' OR 1=1-- -
```

En la Fase 3, este payload devolvía la primera fila de la tabla sin conocer ninguna credencial. Contra `login_seguro.asp`, el texto completo viaja como el valor del parámetro `usuario`: SQL Server busca una fila donde la columna `usuario` sea literalmente igual a `' OR 1=1-- -`, no existe, y el resultado es negativo.

**Resultado obtenido:** **"Usuario o clave incorrectos."**

<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/06-verificacion/3.png" width="600"> </p>
<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/06-verificacion/4.png" width="600"> </p>

---

## 3. Payloads de inyección basada en errores

Los cuatro payloads de la Fase 3, probados uno por uno en el campo _User_ contra `login_seguro.asp`.

### 3.1 Listar bases de datos

```sql
' AND 1=CONVERT(int, (SELECT STRING_AGG(name, ', ') FROM master.dbo.sysdatabases))--
```

**Resultado esperado y obtenido:** "Usuario o clave incorrectos." — sin mensaje de error, sin fuga de nombres de bases de datos. El `CONVERT` nunca llega a ejecutarse como parte de una consulta dinámica: todo el texto del payload, comillas y paréntesis incluidos, es simplemente el valor que se compara contra la columna `usuario`.

<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/06-verificacion/5.png" width="600"> </p>
<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/06-verificacion/6.png" width="600"> </p>

### 3.2 Listar tablas

```sql
' AND 1=CONVERT(int, (SELECT STRING_AGG(table_name, ', ') FROM LabSQLI.INFORMATION_SCHEMA.TABLES WHERE table_type='BASE TABLE'))--
```

**Resultado:** "Usuario o clave incorrectos." Sin error 500, sin detalle de IIS — porque no hay ningún error que generar.

<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/06-verificacion/7.png" width="600"> </p>
<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/06-verificacion/8.png" width="600"> </p>

### 3.3 Listar columnas

```sql
' AND 1=CONVERT(int, (SELECT STRING_AGG(column_name, ', ') FROM LabSQLI.INFORMATION_SCHEMA.COLUMNS WHERE table_name='Usuarios'))--
```

**Resultado:** "Usuario o clave incorrectos."

<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/06-verificacion/9.png" width="600"> </p>
<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/06-verificacion/10.png" width="600"> </p>

### 3.4 Extraer usuarios y contraseñas

```sql
' AND 1=CONVERT(int, (SELECT STRING_AGG(usuario + ':' + clave, ', ') FROM LabSQLI.dbo.Usuarios))--
```

**Resultado:** "Usuario o clave incorrectos." Ningún dato de la tabla `Usuarios` se filtra, ni siquiera el error de conversión que en la Fase 3 traía el contenido pegado en el mensaje.

<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/06-verificacion/11.png" width="600"> </p>
<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/06-verificacion/12.png" width="600"> </p>

---

## 4. Comparación directa: Fase 3 vs. Fase 6

|Payload|Resultado en la Fase 3 (`login.asp`)|Resultado en la Fase 6 (`login_seguro.asp`)|
|---|---|---|
|Login legítimo|Acceso concedido|Acceso concedido (sin cambios)|
|`' OR 1=1-- -`|Acceso concedido sin credenciales|Usuario o clave incorrectos|
|Bases de datos (`sysdatabases`)|Error 500 con el listado de bases en el mensaje|Usuario o clave incorrectos, sin error|
|Tablas (`INFORMATION_SCHEMA.TABLES`)|Error 500 con `Usuarios` revelada|Usuario o clave incorrectos, sin error|
|Columnas (`INFORMATION_SCHEMA.COLUMNS`)|Error 500 con `id, usuario, clave, rol` revelados|Usuario o clave incorrectos, sin error|
|Extracción de credenciales|Error 500 con `admin:Admin1234!`, `jperez:Clave456!`|Usuario o clave incorrectos, sin error|

La columna de la derecha es idéntica en los cuatro payloads de ataque: el mismo mensaje genérico, sin importar qué tan distinto sea el SQL que cada payload intentaba inyectar. Eso es evidencia de que la defensa actúa **antes** de que el contenido del payload llegue a tener efecto — no es que cada payload individual haya sido detectado y bloqueado, es que ninguno llegó a ser código SQL.

---

## 5. Qué confirma esta fase (y qué no)

- **Confirma** que la consulta parametrizada de `login_seguro.asp` neutraliza los cinco vectores probados en este laboratorio, incluidos tanto el bypass de autenticación como la exfiltración de datos vía errores de conversión.
- **No confirma** que `login_seguro.asp` sea invulnerable a cualquier otro tipo de ataque. Esta verificación se limita a repetir los payloads ya documentados en la Fase 3; no es un pentest completo de la aplicación ni cubre otras clases de vulnerabilidad (por ejemplo, XSS, control de sesión, fuerza bruta sobre el login).
- **No depende** de los ajustes de la sección 2 a 5 de la Fase 5 (privilegios de `webuser`, errores ocultos, filtrado de solicitudes). Si se repiten estas mismas pruebas con `webuser` todavía en `db_owner` y los errores detallados todavía activos, el resultado no cambia: la consulta parametrizada por sí sola ya impide que cualquiera de los payloads altere la consulta.

---

## 6. Estado final del laboratorio

|Fase|Objetivo|Estado|
|---|---|---|
|1|SQL Server, base `LabSQLi`, login `webuser`|Completa|
|2|Aplicación web vulnerable (`login.asp`) en IIS|Completa|
|3|Explotación: bypass simple + 4 payloads avanzados|Completa, evidencia capturada|
|4|Revisión de logs de IIS y SQL Server|Completa, limitaciones documentadas|
|5|Remediación: consulta parametrizada, privilegios, errores ocultos|Completa|
|6|Verificación: los 5 payloads fallan contra `login_seguro.asp`, login legítimo intacto|Completa|

Con esto el laboratorio queda cerrado de punta a punta: construcción, explotación, detección y remediación verificada.
