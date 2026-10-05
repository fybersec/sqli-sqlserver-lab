# Seguridad de este repositorio

Este repositorio documenta un laboratorio de inyección SQL **deliberadamente vulnerable**. El código, la configuración y las credenciales que contiene existen para ser atacados y estudiados, no para ser usados como base de un sistema real.

No se acepta ni se gestiona un proceso de *responsible disclosure* sobre las vulnerabilidades documentadas aquí, porque no son fallos accidentales: están descritas, explicadas y explotadas a propósito en **03-ataque-sqli**.

## Vulnerabilidades intencionales

| Elemento | Estado intencional | Documentado en |
|---|---|---|
| Consulta de login (`login.asp`) | Concatenación directa de entrada de usuario, sin parametrizar | **01-sql-server**, **03-ataque-sqli** |
| Contraseñas en la tabla `Usuarios` | Texto plano, sin hash ni sal | **01-sql-server** |
| Usuario `webuser` | Rol `db_owner` sobre `LabSQLi` (privilegio excesivo) | **01-sql-server** |
| Errores detallados de ASP e IIS | Activados, exponen mensajes internos del motor | **02-webapp-login** |

La versión corregida de cada uno de estos puntos está en **05-proteccion**, y la prueba de que la corrección funciona está en **06-verificacion**.

## Alcance de uso permitido

- Entorno de laboratorio aislado, en red NAT u host-only, sin salida pública.
- Máquinas propias o de quienes tengan autorización explícita para participar del laboratorio.
- Fines de aprendizaje, práctica de explotación y práctica de detección/remediación.

## Fuera de alcance / no permitido

- Desplegar este servidor o esta aplicación en una red con acceso desde internet.
- Reutilizar `login.asp`, el esquema de `Usuarios` o las credenciales de prueba en cualquier sistema que maneje datos reales.
- Usar los payloads documentados en **03-ataque-sqli** contra sistemas de terceros sin autorización. Su único propósito es ilustrar la técnica contra el entorno propio de este laboratorio.

## Credenciales de laboratorio

Todas las credenciales que aparecen en la documentación (`admin` / `Admin1234!`, `jperez` / `Clave456!`, `webuser` / `WebPass123!`) son ficticias, generadas para este laboratorio, y no se usan en ningún sistema real. Aun así, no deben reutilizarse como base para contraseñas reales: forman parte del material de ataque documentado.

## Si encontrás un problema con la documentación

Si algo en este repositorio no refleja correctamente la configuración del laboratorio, o hay un paso que podría inducir a desplegar esto de forma insegura por error (por ejemplo, fuera de una red aislada), abrí un issue describiendo el punto exacto. No es un canal de reporte de vulnerabilidades — es un canal de corrección de la documentación.
