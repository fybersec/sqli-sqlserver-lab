# Laboratorio de Inyección SQL — IIS + SQL Server

Laboratorio personal de explotación y detección de inyección SQL, construido sobre un entorno Windows Server con IIS, ASP clásico y SQL Server. El objetivo es cubrir el ciclo completo: preparar el entorno, construir una aplicación de login deliberadamente vulnerable, explotarla, revisar qué evidencia queda en los logs, aplicar la remediación real y verificar que el ataque deja de funcionar.

**Esto no es:**

- Un producto listo para producción.
- Una guía genérica de instalación de SQL Server o IIS — es la documentación de las decisiones específicas tomadas en este entorno.
- Un entorno expuesto a internet. El servidor corre en red NAT/aislada y no debe exponerse en modo bridged.

## Objetivos del laboratorio

- Instalar y configurar SQL Server y una aplicación web ASP clásica con un login intencionalmente vulnerable a inyección SQL.
- Explotar esa vulnerabilidad con dos técnicas: bypass de autenticación simple e inyección basada en errores (error-based), usando `CONVERT` y `STRING_AGG` para enumerar bases de datos, tablas, columnas y credenciales.
- Revisar qué queda registrado del ataque en los logs de IIS y de SQL Server, y qué limitaciones tiene esa visibilidad por defecto.
- Aplicar la remediación real (consulta parametrizada), reducir privilegios y revertir los ajustes inseguros usados para la demostración.
- Verificar, repitiendo los mismos payloads, que la corrección neutraliza el ataque sin romper el uso legítimo.

## Arquitectura general

| Rol | Sistema operativo |
|---|---|
| Servidor víctima (IIS, aplicación web, SQL Server) | Windows Server |
| Equipo atacante | Kali Linux |

Ambas máquinas corren en la misma red virtual en modo NAT: se ven entre sí, pero ningún equipo de la red local puede acceder a ellas por iniciativa propia. El servidor es el único que se construye paso a paso en la documentación, desde la fase de preparación del entorno.

## Alcance y limitaciones

**Dentro de alcance:**

- Un solo servidor Windows con IIS + SQL Server.
- Un ataque de inyección SQL contra un formulario de login propio, con dos técnicas documentadas (bypass simple y error-based).
- Revisión de logs de IIS y SQL Server como evidencia, sin herramientas externas de SIEM.
- Remediación mínima necesaria para neutralizar las técnicas probadas: consulta parametrizada, privilegio mínimo, errores ocultos y una regla de filtrado opcional.

**Fuera de alcance:**

- Otras clases de vulnerabilidad (XSS, control de sesión, fuerza bruta sobre el login).
- Un pentest completo de la aplicación.
- Hardening o compliance certificado del servidor Windows.

## Cómo navegar el repositorio

Las fases están numeradas y pensadas para seguirse en orden, ya que cada una depende del estado dejado por la anterior:

| Fase | Documento | Contenido |
|---|---|---|
| 0 | **00-entorno-vms** | Preparación del entorno: hipervisor, especificaciones de la VM, red, política de snapshots. |
| 1 | **01-sql-server** | Instalación de SQL Server y SSMS, creación de la base `LabSQLi`, la tabla `Usuarios` y el login `webuser`. |
| 2 | **02-webapp-login** | Despliegue de la aplicación web vulnerable sobre IIS (login ASP clásico, conexión a la base, ajustes de errores detallados). |
| 3 | **03-ataque-sqli** | Explotación: bypass de autenticación simple e inyección basada en errores, con los cuatro payloads progresivos de enumeración. |
| 4 | **04-auditoria** | Revisión de los logs de IIS y de SQL Server para evaluar qué evidencia del ataque queda registrada por defecto. |
| 5 | **05-proteccion** | Remediación: consulta parametrizada, reducción de privilegios de `webuser`, reversión de los errores detallados y regla opcional de filtrado de solicitudes. |
| 6 | **06-verificacion** | Repetición de los payloads de la fase de ataque contra la versión corregida, para confirmar que el ataque ya no funciona y que el login legítimo sigue intacto. |

## Stack utilizado

- **Sistema operativo del servidor:** Windows Server
- **Servidor web:** IIS, con aplicación en ASP clásico
- **Base de datos:** SQL Server 2025 (Standard Developer), administrada con SQL Server Management Studio
- **Equipo de ataque:** Kali Linux
- **Hipervisor:** VMware

## Advertencia

Las vulnerabilidades de este laboratorio son intencionales y reales: la base `LabSQLi` guarda contraseñas en texto plano y el login original concatena entrada de usuario directamente en SQL. No reutilices este código ni estas credenciales fuera de un entorno de laboratorio aislado.
