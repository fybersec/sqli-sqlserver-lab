# Fase 5: Remediación y protección

Esta fase corrige la causa raíz de la inyección SQL y revierte cada ajuste inseguro que se activó deliberadamente en las Fases 2 y 3 para poder demostrar el ataque. Es la fase más importante del laboratorio: todo lo anterior (Fases 1-4) existía para poder explotar y observar la vulnerabilidad; esta fase existe para eliminarla.

Esta fase **solo aplica los cambios**. La comprobación de que el ataque ya no funciona se hace aparte, en `06-verificacion.md`, repitiendo los mismos payloads de la Fase 3 contra el resultado de esta fase.

Al terminar se tiene:

- Un `login_seguro.asp` que usa una consulta **parametrizada**, en vez de concatenar texto.
- `webuser` con **privilegio mínimo**, en vez de `db_owner`.
- Los errores detallados de ASP e IIS **desactivados**, como en un entorno de producción real.
- Una regla de **Filtrado de solicitudes** como capa adicional, con su limitación documentada.

> **Requisito previo:** haber completado las Fases 1 a 4.
> 
> **Archivos entregados aparte de este documento:** `login.asp` (el original, limpio de la línea de depuración) y `login_seguro.asp` (el corregido). Ambos van en `C:\inetpub\wwwroot\lab\`, uno junto al otro. `login.asp` se conserva sin tocar, como evidencia del laboratorio.

---

## Resumen de pasos

| #   | Paso                                                    | Resultado                                                       |
| --- | ------------------------------------------------------- | --------------------------------------------------------------- |
| 1   | Colocar `login_seguro.asp` junto al original            | Existen dos versiones del login, una vulnerable y una corregida |
| 2   | Reducir los privilegios de `webuser`                    | De `db_owner` a solo lo necesario para el login                 |
| 3   | Revertir los errores detallados de ASP                  | `Enviar errores al explorador` → `False`                        |
| 4   | Revertir los errores detallados de IIS                  | `Páginas de errores` → valor predeterminado                     |
| 5   | (Opcional) Agregar una regla de Filtrado de solicitudes | Bloquea patrones de inyección conocidos en la URL               |

---

## 1. Consulta parametrizada: qué cambió en el archivo

### 1.1 Por qué esto es la corrección real

Todo lo demás en esta fase (privilegios, errores ocultos, filtrado) reduce el **impacto** o la **visibilidad** de un ataque, pero no elimina la vulnerabilidad. La única corrección que ataca la causa es dejar de construir el SQL por concatenación de texto. El resto son medidas de defensa en profundidad, no la solución.

### 1.2 Cómo construía la consulta el archivo original (`login.asp`)

```asp
sql = "SELECT * FROM Usuarios WHERE usuario='" & usuarioInput & _
  "' AND clave='" & clave & "'"
...
Set rs = conn.Execute(sql)
```

Aquí `sql` termina siendo una sola cadena de texto. `usuarioInput` y `clave` se **pegan dentro de esa cadena**, entre comillas simples, antes de que la cadena se envíe a SQL Server. SQL Server no tiene forma de distinguir "esto es un dato que escribió el usuario" de "esto es parte de la consulta": para el motor, todo lo que llega en `sql` es código SQL a ejecutar. Por eso, si `usuarioInput` contiene una comilla (`'`), esa comilla cierra el valor del campo `usuario` antes de tiempo, y lo que venga después pasa a interpretarse como SQL real.

### 1.3 Cómo construye la consulta el archivo corregido (`login_seguro.asp`)

```asp
Set cmd = Server.CreateObject("ADODB.Command")
cmd.ActiveConnection = conn
cmd.CommandText = "SELECT * FROM Usuarios WHERE usuario = ? AND clave = ?"
cmd.CommandType = 1 ' adCmdText

cmd.Parameters.Append cmd.CreateParameter("p_usuario", 200, 1, 50, usuario)
cmd.Parameters.Append cmd.CreateParameter("p_clave",   200, 1, 50, clave)

Set rs = cmd.Execute()
```

Los cambios concretos respecto al original:

|Elemento|Antes (`login.asp`)|Ahora (`login_seguro.asp`)|Por qué importa|
|---|---|---|---|
|Objeto que ejecuta|`ADODB.Connection`, con `conn.Execute(sql)` sobre una cadena ya armada.|`ADODB.Command`, con `cmd.Execute()`.|`Command` permite declarar una consulta con **marcadores de posición** (`?`) y enviar los valores por separado, en vez de como texto.|
|Dónde está el texto SQL|Se arma en tiempo de ejecución, variable (`sql`), distinto cada vez según lo que escribió el usuario.|Fijo, en `cmd.CommandText`: siempre es exactamente `SELECT * FROM Usuarios WHERE usuario = ? AND clave = ?`, nunca cambia.|Como el texto de la consulta no depende de la entrada, no hay forma de alterar su estructura desde el formulario.|
|Dónde van `usuario` y `clave`|Concatenados dentro de `sql`, como texto.|Pasados aparte, con `cmd.CreateParameter(...)` y `cmd.Parameters.Append`.|El driver OLE DB los envía a SQL Server **por el canal de datos, no por el de comandos**. SQL Server los trata como un valor a comparar, nunca como sintaxis SQL, sin importar qué caracteres contengan.|
|Tipo de cada parámetro (`200`)|No existía.|`adVarChar`: le dice a SQL Server qué tipo de dato esperar.|Si alguien escribe algo que no calza con el tipo esperado, el motor simplemente lo trata como texto o lo rechaza por tipo, nunca lo ejecuta.|
|Tamaño de cada parámetro (`50`)|No existía.|Límite de caracteres del parámetro.|Debe ser mayor o igual que el ancho real de las columnas `usuario` y `clave` en la tabla; si una columna es más ancha, hay que subir este número.|

### 1.4 Qué significa esto para un atacante

Si alguien escribe `' OR 1=1-- -` en el campo de usuario contra `login_seguro.asp`, ese texto completo — comillas, espacios, guiones incluidos — viaja como el **valor** del parámetro `p_usuario`. SQL Server busca una fila donde la columna `usuario` sea literalmente igual al texto `' OR 1=1-- -`. Como ninguna fila de `Usuarios` tiene ese valor, la consulta simplemente no devuelve resultados: ni hay error, ni hay bypass, ni hay fuga de datos. El atacante no logra que SQL Server ejecute nada distinto de "comparar una columna contra un valor".

---

## 2. Mínimo privilegio para `webuser`

### 2.1 Por qué

En la Fase 1, `webuser` se creó con el rol `db_owner` sobre `LabSQLi` para maximizar el impacto de la demostración. En un sistema real, la cuenta que usa una aplicación web para autenticar usuarios **no necesita** poder crear tablas, modificar el esquema ni leer el resto de la base — solo necesita leer la tabla `Usuarios`.

### 2.2 Cómo se reduce

1. En SSMS, expandir **LabSQLi → Seguridad → Usuarios**, clic derecho sobre `webuser` → **Propiedades**.
2. En la página **Membresía de roles de base de datos**, **desmarcar** `db_owner`.
3. Cerrar con **Aceptar**.
4. Conceder el permiso mínimo explícito, ejecutando en una consulta nueva sobre `LabSQLi`:

```sql
GRANT SELECT ON dbo.Usuarios TO webuser;
```

### 2.3 El límite real de esta medida

Esto conviene tenerlo claro de una vez, antes de llegar a la Fase 6: reducir privilegios **no cierra** la inyección de este laboratorio. Los metadatos de `INFORMATION_SCHEMA` y de `sysdatabases` son legibles con privilegios mínimos (ya se documentó en la Fase 3), y el permiso que necesita la app legítima sobre `Usuarios` (`SELECT`) es exactamente el mismo que necesitaría un atacante para leer esa tabla por inyección. Es una buena práctica de defensa en profundidad, pero la corrección que efectivamente bloquea el ataque es la de la sección 1.

---

## 3. Revertir los errores detallados de ASP

1. En el Administrador de IIS, seleccionar **Default Web Site** → abrir **ASP** → **Propiedades de depuración**.
2. Cambiar **Enviar errores al explorador** de `True` de vuelta a **`False`**.
3. **Aplicar**.

Con esto, cualquier error de ASP vuelve a mostrar el mensaje genérico _"An error occurred on the server..."_, sin revelar proveedor, consulta ni estructura interna.

<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/05-proteccion/1.png" width="600"> </p>

---

## 4. Revertir los errores detallados de IIS

1. En el árbol de conexiones, bajar a **Sitios → Default Web Site → lab**.
2. Doble clic en **Páginas de errores**.
3. **Modificar configuración de característica...**
4. Volver a seleccionar **"Errores detallados para solicitudes locales y páginas de error personalizadas para solicitudes remotas"** (el valor predeterminado, el que estaba antes de la Fase 2, sección 7).
5. **Aceptar**.

<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/05-proteccion/2.png" width="600"> </p>

---

## 5. Resumen de todas las decisiones revertidas

|Decisión insegura (Fases 1-3)|Estado al final de la Fase 5|
|---|---|
|Consulta SQL por concatenación|Reemplazada por consulta parametrizada en `login_seguro.asp`. `login.asp` original se conserva sin cambios, como evidencia del laboratorio.|
|`webuser` con rol `db_owner`|Reducido a `SELECT` sobre `dbo.Usuarios` únicamente.|
|ASP: Enviar errores al explorador|`True` → `False`.|
|IIS: Páginas de errores (carpeta `lab`)|`Errores detallados` → valor predeterminado.|
|Sin Filtrado de solicitudes activo|Regla básica agregada, con su limitación (solo GET) documentada.|

---

## 6. Estado final de la fase

|Elemento|Valor|
|---|---|
|Script corregido|`C:\inetpub\wwwroot\lab\login_seguro.asp`|
|Técnica de corrección|Consulta parametrizada (`ADODB.Command` + `CreateParameter`)|
|Privilegio de `webuser`|`SELECT` sobre `dbo.Usuarios` (sin `db_owner`)|
|Errores detallados de ASP|`False`|
|Errores detallados de IIS (carpeta `lab`)|Valor predeterminado|
|Filtrado de solicitudes|Regla opcional agregada, cobertura parcial (solo GET)|

Siguiente fase: `06-verificacion.md`, donde se repiten los payloads de la Fase 3 contra esta configuración para confirmar que ya no son funcionales.
