# Fase 3: Ataque de inyección SQL

Esta fase explota la vulnerabilidad construida en la Fase 2: `login.asp` arma la consulta SQL concatenando directamente lo que escribe el usuario, sin validarlo ni separarlo del código SQL. Se demuestran dos niveles de ataque:

1. **Bypass de autenticación simple** — entra sin conocer ninguna contraseña.
2. **Inyección SQL basada en errores (error-based)** — con el login ya sin usarse como objetivo, se usa el mismo campo para leer el contenido completo de la base de datos: sus nombres, sus tablas, sus columnas y, al final, las credenciales de todos los usuarios.

> **Requisito previo:** haber completado la Fase 2, con el formulario funcionando en `http://localhost/lab/` y **Enviar errores al explorador = True** en la configuración de ASP (Fase 2, sección 6). El segundo tipo de ataque de esta fase depende por completo de que esa opción esté activa: es la vía por la que los datos salen del servidor.

---

## 1. Por qué el formulario es vulnerable

En `login.asp`, la consulta se arma así (ver Fase 2, sección 8):

```asp
sql = "SELECT * FROM Usuarios WHERE usuario='" & usuarioInput & "' AND clave='" & clave & "'"
```

`usuarioInput` y `clave` son exactamente lo que la persona escribió en el formulario, pegado tal cual dentro de las comillas. El servidor no distingue entre "esto es un dato" y "esto es código SQL": todo lo que llega se convierte en parte de la instrucción que se ejecuta. Esa falta de separación entre datos y código es, en una frase, lo que es una inyección SQL.

---

## 2. Bypass de autenticación simple

### 2.1 El payload

En el campo **User** se escribe:

```
' OR 1=1-- -
```

En el campo **Password** se puede escribir cualquier cosa, o dejarlo vacío.

### 2.2 Qué hace cada parte

|Fragmento|Función|
|---|---|
|`'`|Cierra anticipadamente la comilla que abre `usuario='`. A partir de aquí, lo que sigue ya no es un valor de texto: SQL Server lo interpreta como parte de la condición `WHERE`.|
|`OR 1=1`|Agrega una condición que **siempre es verdadera**, sin importar el contenido de la tabla.|
|`--`|Inicia un comentario de línea en T-SQL. Todo lo que venga después, en la misma línea, se ignora.|
|`-` (espacio y guion después de `--`)|No cambia el efecto del comentario; es solo una convención visual para que el `--` no quede pegado al final de la línea y se note con claridad en la documentación.|

### 2.3 Cómo queda la consulta real

Con ese payload en **User** y, por ejemplo, `x` en **Password**, el texto que `login.asp` arma y envía a SQL Server es:

```sql
SELECT * FROM Usuarios WHERE usuario='' OR 1=1-- -' AND clave='x'
```

El `--` comenta desde ahí hasta el final de la línea, así que SQL Server en realidad solo ve:

```sql
SELECT * FROM Usuarios WHERE usuario='' OR 1=1
```

La cláusula `WHERE` queda reducida a `OR 1=1`, que es verdadera para **todas** las filas de la tabla `Usuarios`. La consulta devuelve la tabla completa, sin haber acertado ninguna contraseña. Como `login.asp` solo revisa si `rs.EOF` es falso (es decir, si vino al menos una fila) para mostrar "Acceso concedido", el script concede el acceso con el primer registro que encuentra.

### 2.4 Resultado esperado

El navegador debe mostrar **"Acceso concedido. Bienvenido admin"** (o el primer usuario de la tabla), sin haber escrito ninguna contraseña válida.

<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/03-ataque-sqli/1.png" width="600"> </p>
<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/03-ataque-sqli/2.png" width="600"> </p>

### 2.5 Qué demuestra y qué no

Este payload demuestra que **la autenticación se puede evadir**. No revela nada sobre el contenido de la base de datos: no dice qué otras tablas existen, ni cuántas columnas tiene `Usuarios`, ni cuáles son las contraseñas reales. Para eso se necesita una técnica distinta, que se explica a continuación.

---

## 3. Inyección SQL basada en errores (error-based)

### 3.1 La idea general

Esta técnica no intenta que la consulta `SELECT * FROM Usuarios ...` devuelva una fila válida. En cambio, **fuerza deliberadamente un error de SQL Server** y aprovecha que, gracias a la opción activada en la Fase 2 (_Enviar errores al explorador_), el mensaje de error completo se muestra en el navegador. El dato que se quiere robar se mete dentro de ese mensaje de error, para leerlo directamente en la página.

El mecanismo que se usa para provocar el error es la función `CONVERT`.

### 3.2 La pieza clave: `CONVERT(int, ...)`

`CONVERT(tipo, valor)` le pide a SQL Server que convierta `valor` al tipo de dato indicado. Si `valor` es una cadena de texto que **no se puede interpretar como un número entero**, SQL Server no puede hacer la conversión y lanza un error. Ese error trae incluido, dentro de su propio mensaje, la cadena de texto que no pudo convertir.

Es decir: `CONVERT(int, (SELECT ...))` no se usa para que la conversión funcione, se usa **para que falle a propósito**, y ese fallo imprime en pantalla el resultado de la subconsulta que va dentro.

### 3.3 La pieza que junta varios resultados: `STRING_AGG`

Una subconsulta como `SELECT name FROM master.dbo.sysdatabases` puede devolver varias filas (varios nombres de bases de datos). `CONVERT` solo puede recibir un único valor, no una lista de filas. `STRING_AGG(columna, separador)` resuelve eso: toma todas las filas de esa columna y las une en un solo texto, separadas por el separador indicado (aquí, `,` ).

Con `STRING_AGG`, muchas filas se convierten en una sola cadena larga, que es justo lo que `CONVERT` necesita para poder fallar y mostrarla entera en el mensaje de error.

### 3.4 Estructura común de los cuatro payloads

Los cuatro ataques comparten exactamente la misma forma:

```
' AND 1=CONVERT(int, (SELECT STRING_AGG(<columna>, ', ') FROM <tabla>))--
```

|Fragmento|Función|
|---|---|
|`'`|Cierra la comilla de `usuario='`, igual que en el bypass simple.|
|`AND 1=CONVERT(...)`|Agrega una condición que obliga a SQL Server a evaluar la conversión forzada. No importa si el resultado sería verdadero o falso: el error ocurre antes de que se pueda comparar nada.|
|`(SELECT STRING_AGG(...) FROM ...)`|La subconsulta que realmente interesa: cambia en cada uno de los cuatro pasos.|
|`--`|Comenta el resto de la línea original (el `' AND clave='...'` que `login.asp` agrega después), igual que antes.|

Cada uno de los cuatro payloads solo cambia qué se le pide a `STRING_AGG` y de dónde. Es un ataque progresivo: cada paso usa el resultado del anterior.

---

### Paso 1 — Listar las bases de datos del servidor

```sql
' AND 1=CONVERT(int, (SELECT STRING_AGG(name, ', ') FROM master.dbo.sysdatabases))--
```

- `master` es la base de datos del sistema que existe en todo SQL Server y guarda, entre otras cosas, el catálogo de todas las demás bases de datos instaladas en el servidor.
- `sysdatabases` es la tabla de ese catálogo; su columna `name` tiene el nombre de cada base de datos.
- `STRING_AGG(name, ', ')` une todos esos nombres en una sola cadena.
- `CONVERT(int, ...)` falla al intentar convertir esa cadena a número, y el mensaje de error la muestra completa.

**Resultado obtenido:** el mensaje de error reveló, entre las bases del sistema (`master`, `tempdb`, `model`, `msdb`), la base creada para el laboratorio: **`LabSQLI`**.

<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/03-ataque-sqli/3.png" width="600"> </p>
<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/03-ataque-sqli/4.png" width="600"> </p>

> Este paso no depende de nada de la aplicación en particular: funciona igual contra cualquier SQL Server vulnerable a esta técnica, porque `master.dbo.sysdatabases` siempre existe.

---

### Paso 2 — Listar las tablas de `LabSQLI`

Con el nombre de la base ya en mano, el siguiente payload busca dentro de ella:

```sql
' AND 1=CONVERT(int, (SELECT STRING_AGG(table_name, ', ') FROM LabSQLI.INFORMATION_SCHEMA.TABLES WHERE table_type='BASE TABLE'))--
```

- `INFORMATION_SCHEMA.TABLES` es una vista estándar de SQL (no es específica de SQL Server) que lista los objetos de tipo tabla o vista de una base de datos.
- Anteponer `LabSQLI.` apunta la consulta a esa base de datos en concreto, aunque la conexión de `webuser` esté, en principio, sobre otra.
- `WHERE table_type='BASE TABLE'` filtra para quedarse solo con tablas reales, dejando fuera las vistas.
- `STRING_AGG(table_name, ', ')` une los nombres de todas las tablas encontradas.

**Resultado obtenido:** el mensaje de error reveló el nombre de la tabla de interés: **`Usuarios`**.

<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/03-ataque-sqli/5.png" width="600"> </p>
<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/03-ataque-sqli/6.png" width="600"> </p>

> **Por qué esto es posible:** `webuser` tiene el rol `db_owner` sobre `LabSQLi` (ver Fase 1, sección 8), pero además `INFORMATION_SCHEMA` es legible por cualquier usuario que tenga algún permiso sobre esa base, incluso con privilegios mínimos. Reducir el privilegio de `webuser` (Fase 5) no habría evitado este paso en concreto; lo que sí evita toda la fase es corregir la vulnerabilidad de origen en `login.asp`.

---

### Paso 3 — Listar las columnas de `Usuarios`

```sql
' AND 1=CONVERT(int, (SELECT STRING_AGG(column_name, ', ') FROM LabSQLI.INFORMATION_SCHEMA.COLUMNS WHERE table_name='Usuarios'))--
```

- Mismo mecanismo que el paso 2, pero sobre `INFORMATION_SCHEMA.COLUMNS`, que lista las columnas de las tablas.
- `WHERE table_name='Usuarios'` filtra para quedarse solo con las columnas de la tabla encontrada en el paso anterior.

**Resultado obtenido:** el mensaje de error reveló la estructura completa de la tabla: **`id, usuario, clave, rol`**, exactamente las columnas definidas en la Fase 1.

<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/02-webapp-login/7.png" width="600"> </p>
<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/03-ataque-sqli/8.png" width="600"> </p>

> En este punto, sin haber leído todavía ni una sola contraseña, ya se conoce el nombre exacto de la columna que las guarda (`clave`). Eso es lo que hace tan dañino a este patrón de enumeración: cada paso reduce la incertidumbre del siguiente.

---

### Paso 4 — Extraer los datos de la tabla `Usuarios`

```sql
' AND 1=CONVERT(int, (SELECT STRING_AGG(usuario + ':' + clave, ', ') FROM LabSQLI.dbo.Usuarios))--
```

- Esta vez la subconsulta ya no lee el catálogo del sistema, sino la tabla de datos real: `LabSQLI.dbo.Usuarios`.
- `usuario + ':' + clave` concatena, fila por fila, el nombre de usuario y su contraseña, separados por `:`. El operador `+` es el operador de concatenación de cadenas en T-SQL (equivalente a `||` en otros motores SQL).
- `STRING_AGG(..., ', ')` une todas esas filas `usuario:clave` en un solo texto.

**Resultado obtenido:** el mensaje de error reveló el contenido completo de la tabla:

```
admin:Admin1234!, jperez:Clave456!
```

<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/03-ataque-sqli/9.png" width="600"> </p>
<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/03-ataque-sqli/10.png" width="600"> </p>

En un solo mensaje de error quedaron expuestas las credenciales de **todos** los usuarios de la aplicación, administrador incluido, sin haber adivinado ninguna contraseña: se leyeron directamente de la base de datos.

---

## 4. Por qué funciona de principio a fin (resumen técnico)

Esta técnica depende de la combinación de tres condiciones, todas presentes en este laboratorio:

|Condición|Dónde se originó|
|---|---|
|La entrada del usuario se concatena sin separación en una consulta SQL|`login.asp` (Fase 2)|
|Los mensajes de error detallados de SQL Server llegan hasta el navegador|_Enviar errores al explorador = True_ (Fase 2, sección 6)|
|El usuario de conexión (`webuser`) tiene permisos suficientes para leer el catálogo y los datos|Rol `db_owner` (Fase 1, sección 8)|

Si cualquiera de las tres se elimina, la técnica deja de funcionar tal como está documentada aquí:

- Sin concatenación directa (usando una consulta parametrizada), el apóstrofo del payload se trata como un carácter de texto normal y nunca llega a alterar la estructura de la consulta.
- Sin errores detallados, el `CONVERT` sigue fallando, pero el navegador solo ve el error genérico de IIS: el dato robado nunca sale del servidor por esta vía.
- Con privilegios mínimos, cambia qué se puede leer, pero no necesariamente impide la inyección en sí: por eso la verdadera corrección es la consulta parametrizada, no solo el ajuste de privilegios.

La corrección completa de los tres puntos se documenta en la Fase 5.

---

## 5. Estado final de la fase

| Elemento                 | Resultado                                                                                                                 |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------- |
| Técnica 1                | Bypass de autenticación con `' OR 1=1-- -` — acceso concedido sin contraseña válida                                       |
| Técnica 2                | Inyección basada en errores con `CONVERT` + `STRING_AGG` — enumeración completa de bases, tablas, columnas y credenciales |
| Bases de datos reveladas | `master`, `tempdb`, `model`, `msdb`, `LabSQLI`                                                                            |
| Tabla objetivo revelada  | `Usuarios`                                                                                                                |
| Columnas reveladas       | `id`, `usuario`, `clave`, `rol`                                                                                           |
| Credenciales extraídas   | `admin:Admin1234!`, `jperez:Clave456!`                                                                                    |

Siguiente fase: `04-auditoria.md`, donde se configura una auditoría en SQL Server para detectar este mismo ataque en el registro.
