# Fase 4: Evidencia y detección (logs)

Esta fase busca la huella que dejó el ataque de la Fase 3 en los registros del servidor, antes de aplicar la remediación de la Fase 5. El objetivo es responder, con evidencia, tres preguntas: **qué se pidió**, **desde dónde** y **cuándo**.

Hay dos fuentes de log relevantes, independientes entre sí:

- **Logs de IIS**: registran cada petición HTTP, incluida la cadena de consulta con el payload de inyección.
- **Logs de SQL Server**: registran errores del motor y, si se configura, los inicios de sesión de `webuser`.

> **Requisito previo:** haber completado la Fase 3 (payloads ejecutados, al menos uno exitoso desde Kali).

---

## Resumen de pasos

|#|Paso|Resultado|
|---|---|---|
|1|Ubicar y abrir el log de IIS del sitio|Archivo `u_exYYMMDD.log` con las peticiones del día|
|2|Interpretar las columnas del log W3C|Identificar `cs-uri-query`, `c-ip`, `sc-status`|
|3|Filtrar las peticiones con el payload de inyección|Línea exacta de cada ataque, con hora e IP de origen|
|4|Revisar el log de errores de SQL Server|Confirmar si el motor registró los errores de conversión (`CONVERT`)|
|5|(Opcional) Revisar el Visor de eventos de Windows|Ver si hubo intentos de inicio de sesión fallidos de `webuser`|

---

## 1. Logs de IIS

### 1.1 Ubicación

Por configuración predeterminada, IIS guarda un archivo de log por día en:

```
C:\inetpub\logs\LogFiles\W3SVC1\
```

El `1` corresponde al ID del sitio (`Default Web Site`). El nombre de archivo sigue el patrón `u_exAAMMDD.log` (por ejemplo, `u_ex261004.log` para el 4 de octubre de 2026).

> Si la carpeta no existe o aparece vacía, verificar en el Administrador de IIS: **Default Web Site → Registro** → confirmar que el registro está **Habilitado** y que la ruta del directorio coincide con la de arriba.

<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/04-auditoria/1.png" width="600"> </p>

### 1.2 Formato del log

IIS usa por defecto el **formato de archivo de registro ampliado W3C**. El archivo es texto plano, delimitado por espacios, y empieza con líneas `#` que son metadatos, no peticiones. La línea `#Fields:` indica el orden exacto de las columnas de ese archivo:

```
x0x6-1x-0x x2:2x:5x 1x2.168.250.1x9 POST /lab/login.asp - 80 - 192.1x8.2x0.129 Mozilla/5.0+(X11;+Linux+x86_64;+rv:140.0)+Gecko/20100101+Firefox/140.0 http://1x2.16x.2x0.x39/lab/ 200 0 0 9
```


> **Nota importante sobre POST:** el formulario de `login.asp` envía los datos por **POST**, no por GET. El log estándar de IIS (W3C) **no registra el cuerpo de una petición POST**, así que el usuario y la contraseña (o el payload de inyección, si se probó desde el formulario) no aparecen en `cs-uri-query`. Si los payloads de la Fase 3 se probaron con una herramienta que los mandó por GET (por ejemplo, anexando `?User=...` a la URL, o con `curl -G`), sí van a aparecer. Si se probaron tal cual el formulario los envía (POST), el log de IIS va a mostrar la petición — método, hora, IP, status — pero no el contenido exacto del payload. Esa limitación en sí misma es un hallazgo útil para la Fase 5 (ver sección 4).

### 1.3 Abrir y leer el archivo

El Bloc de notas sirve para archivos pequeños, pero las líneas son largas. Es más cómodo:

1. Abrir el archivo con el Bloc de notas (o Notepad++ si está disponible).
2. Activar **Ajuste de línea** (Formato → Ajuste de línea) para no perder columnas fuera de pantalla.
3. Ubicar la línea `#Fields:` al inicio para saber el orden de las columnas de ese archivo en particular (puede variar si se reconfiguró el registro).

<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/04-auditoria/2.png" width="600"> </p>

### 1.4 Filtrar las peticiones del ataque

Para encontrar las líneas del ataque sin leer todo el archivo, usar **Buscar** (Ctrl+F) con alguno de estos criterios:

|Buscar|Para encontrar|
|---|---|
|La IP de la Kali (por ejemplo `192.168.x.x`)|Todas las peticiones hechas desde esa máquina.|
|`/lab/login.asp`|Todas las peticiones al script vulnerable (de cualquier origen).|
|`500` (en la columna `sc-status`)|Las peticiones que devolvieron error — útiles para ubicar los payloads de inyección basada en errores de la Fase 3, antes de corregir el ajuste de la Fase 2 sección 7.|

<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/04-auditoria/3.png" width="600"> </p>

Con esto se puede reconstruir la secuencia: hora del bypass simple, hora de cada uno de los cuatro payloads avanzados, y el cambio de `sc-status` de `500` a `200` en el momento en que se activó "Errores detallados" en IIS (Fase 2, sección 7).

---

## 2. Logs de SQL Server

### 2.1 Log de errores del motor

SQL Server guarda su propio log de errores, independiente del de IIS. Se revisa desde SSMS:

1. Abrir **SQL Server Management Studio** y conectar a la instancia.
2. En el **Explorador de objetos**, expandir **Administración → Registros de SQL Server**.
3. Doble clic en el log más reciente (**Actual**).

<p align="center"> <img src="https://github.com/fybersec/sqli-sqlserver-lab/blob/main/evidencias/04-auditoria/4.png" width="600"> </p>

Qué buscar:

- Mensajes de **inicio de sesión fallido** (`Login failed for user 'webuser'`), si se probaron credenciales incorrectas en algún punto.
- El log de errores del motor normalmente **no registra el texto de cada consulta** que falla por `CONVERT`, salvo que se haya habilitado explícitamente **Auditoría de SQL Server** o una sesión de **Extended Events**. Por defecto, esos errores de conversión solo los ve quien recibe la respuesta (el navegador o, en la Fase 3, el atacante vía IIS) — el motor no los escribe a disco como incidente de seguridad.

> **Hallazgo para documentar:** esta es una pieza clave de la fase. Los errores de `CONVERT(int, ...)` que hicieron posible la extracción de datos en la Fase 3 **no dejan rastro en el log de errores de SQL Server por defecto**. Solo quedan en el log de IIS (como código `500`, sin el detalle) y, si se usó alguna herramienta en la Kali para capturar la respuesta completa, en esa captura. Sin habilitar auditoría, SQL Server es "ciego" a este tipo de ataque desde su propio log.


---

## 4. Conclusiones de la fase (para conectar con la Fase 5)

|Fuente de log|Qué sí se ve|Qué no se ve|Implicación para la Fase 5|
|---|---|---|---|
|IIS (`cs-uri-query`)|Payloads enviados por **GET**, IP de origen, hora, código de estado.|El cuerpo de peticiones **POST** (como las del formulario real de login).|El **Filtrado de solicitudes** (ya instalado en la Fase 2) puede bloquear patrones conocidos en la URL, pero una regla pensada solo para GET no cubre el vector real de este laboratorio, que es POST.|
|SQL Server (log de errores)|Inicios de sesión fallidos, si los hay.|El texto de las consultas ni los errores de `CONVERT` que explotó la Fase 3, salvo que se habilite auditoría.|Sin auditoría a nivel de base de datos, un ataque de este tipo puede pasar completamente inadvertido para el DBA.|

Esta tabla es la base de las recomendaciones de la Fase 5: no basta con corregir el código (consulta parametrizada); conviene además dejar algún mecanismo de auditoría activo si el escenario se usa para practicar detección, no solo explotación.

---

## 5. Estado final de la fase

| Elemento                   | Valor                                                                                                                                                                                    |
| -------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Log de IIS revisado        | `C:\inetpub\logs\LogFiles\W3SVC1\u_exAAMMDD.log`                                                                                                                                         |
| Formato de log             | W3C ampliado                                                                                                                                                                             |
| Log de SQL Server revisado | Registros de SQL Server (Actual), vía SSMS                                                                                                                                               |

Siguiente fase: `05-remediacion.md`.
