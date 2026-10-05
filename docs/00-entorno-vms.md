# Fase 0: Entorno de máquinas virtuales

Esta fase describe cómo se prepara el entorno donde corre todo el laboratorio: las máquinas virtuales, sus recursos, la red y la política de _snapshots_.

[Instalacion de VMware](https://www.vmware.com/)
## Contenido

1. Arquitectura del laboratorio
2. Las dos formas de crear una VM
3. Método usado en este laboratorio
4. Especificaciones de la VM Windows Server
5. Red
6. Política de snapshots
7. Instalación de VMware Tools
8. Equivalencias en otros hipervisores
9. Estado final de la fase

---

## 1. Arquitectura del laboratorio

|Máquina|Rol|Sistema operativo|
|---|---|---|
|Servidor víctima|Aloja IIS, la aplicación web de login y SQL Server|Windows Server|
|Equipo atacante|Ejecuta el ataque de la Fase 3|Kali Linux|

Ambas máquinas se conectan a una misma red virtual en modo **NAT** (sección 5). El servidor víctima es el único que se construye paso a paso en esta documentación, desde la Fase 1.

---

## 2. Las dos formas de crear una VM

#### 2.1 Instalación tradicional (manual) desde ISO

Se crea la VM, se conecta la imagen ISO del sistema operativo y se arranca desde ella. El asistente del propio sistema operativo (en Windows, _Windows Setup_) pregunta todo de forma interactiva: idioma, edición, particiones, contraseña del administrador, etc.

- **Ventajas:** control total de cada decisión; es el proceso real que se sigue en un servidor físico; sirve para aprender y documentar cada paso.
- **Desventajas:** más lento y con más pasos manuales; hay que instalar después las herramientas de integración del hipervisor.

#### 2.2 "Easy Install" de VMware (instalación asistida)

Cuando el asistente de VMware recibe una ISO de un sistema operativo que reconoce, ofrece la instalación fácil: pide por adelantado el nombre de usuario, la contraseña y, en Windows, la clave de producto, y después instala el sistema **sin intervención** y también instala VMware Tools.

- **Ventajas:** rápida y casi automática.
- **Desventajas:** oculta las decisiones del sistema operativo (particionado, edición, cuenta de administrador, ajustes iniciales); da menos control y deja menos que documentar.

---

## 3. Método usado en este laboratorio

Se usó la **instalación tradicional (manual)**, y para lograrlo hubo que evitar que VMware activara Easy Install. El procedimiento fue:

1. **Crear la VM sin la ISO.** Al crear la máquina no se seleccionó el archivo ISO en el asistente. Si se hace, VMware detecta el sistema operativo y activa Easy Install. En su lugar se crea la VM "vacía" (sin sistema operativo) y se configura el hardware a mano.
2. **Cambiar el disco por uno SCSI.** Antes de encender la VM se eliminó el disco virtual que proponía el asistente y se agregó uno nuevo de tipo **SCSI**(por alguna extraña razon, el controlador por defecto estaba dando error), de 70 GB.
3. **Agregar la ISO después de crear la VM.** Desde la configuración de la VM, en la unidad de CD/DVD, se seleccionó el archivo ISO de Windows Server como _Usar archivo de imagen ISO_, con la opción _Conectar al encender_ activa.
4. **Encender la VM y ejecutar el instalador de Windows manualmente.** Idioma, edición, instalación personalizada sobre el disco de 70 GB y contraseña del administrador se eligieron a mano.


### Por qué importa el tipo de controlador de disco

El tipo de controlador (SCSI, SATA, NVMe, etc.) determina qué driver necesita el sistema operativo para ver el disco. El instalador de Windows solo incluye drivers de ciertos controladores; si el tipo elegido no tiene driver integrado, el instalador muestra la lista de discos vacía y pide cargar un driver. Un controlador SCSI estándar suele estar soportado sin pasos extra, por eso es una elección segura para una instalación manual.

### Por qué la ISO se agrega después

El orden importa por dos motivos:

- Si la ISO se selecciona en el asistente de creación, VMware puede activar Easy Install y saltarse la instalación manual.
- Tener primero la VM creada y el hardware definido permite revisarlo todo (disco, CPU, memoria, red) antes del primer arranque, que es lo que se documenta aquí.

---

## 4. Especificaciones de la VM Windows Server

| Recurso          | Valor                                                   | Observaciones                                                                                                                                                          |
| ---------------- | ------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Procesadores     | 4 CPU virtuales                                         | Suficiente para IIS y SQL Server sin ralentizar el host.                                                                                                               |
| Memoria RAM      | 5 GB                                                    | Para Windows Server con interfaz gráfica, IIS, SQL Server y SSMS.                                                                                                      |
| Disco            | 70 GB, controlador **SCSI**                             | Una sola partición de sistema. Se reserva espacio para los archivos de instalación de SQL Server (la descarga del medio ocupa varios GB), SSMS y los datos de la base. |
| Unidad de CD/DVD | ISO de Windows Server (agregada después de crear la VM) | Se puede desconectar al terminar la instalación.                                                                                                                       |
| Red              | NAT                                                     | Ver sección 5.                                                                                                                                                         |

### Notas sobre el dimensionamiento

- Los recursos asignados a la VM se restan del equipo anfitrión mientras la VM está encendida. Con la VM de Kali también activa, hay que dejar memoria suficiente al sistema anfitrión.
- Los valores se pueden aumentar después si la VM va lenta. Reducirlos exige apagarla y suele ser más molesto.

---
## 5. Red

### 5.1 Modos de red más comunes en VMware

|Modo|Qué hace|Cuándo se usa|
|---|---|---|
|**NAT**|La VM comparte la dirección IP del anfitrión para salir a internet. Las VMs conectadas a la misma red NAT se ven entre sí, pero la red local del anfitrión no puede entrar a ellas por iniciativa propia.|Laboratorios con internet para descargar software.|
|Host-only|Red privada solo entre el anfitrión y las VMs, **sin salida a internet**.|Ataques entre VMs sin riesgo de salir a internet.|
|Bridged (puente)|La VM aparece como un equipo más de la red física.|Cuando otros equipos físicos deben acceder a la VM.|

### 5.2 Modo elegido: NAT

Se eligió **NAT** por ahora, porque durante la construcción del laboratorio la VM necesita internet para descargar SQL Server, SSMS, el driver OLE DB y la plantilla del formulario. En esta configuración:

- El servidor y Kali comparten la misma red virtual y se ven entre sí. El ataque de la Fase 3 viaja por esa red.
- Ningún equipo de la red local puede acceder a las VMs por iniciativa propia.

> **Matiz de seguridad:** NAT aísla las VMs de la red local, pero **no** las deja sin internet. Por eso, el servidor vulnerable no debe exponerse nunca en modo _bridged_. Si más adelante se quiere un aislamiento total para la fase de ataque, se puede pasar ambas VMs a _host-only_ una vez descargado todo el software.

---

## 6. Política de snapshots

Un _snapshot_ guarda el estado completo de la VM (disco, y opcionalmente memoria) en un momento dado, y permite volver a él. Se tomaron **antes y después** de cada etapa importante, para poder repetir una fase sin reinstalar todo.

|Momento|Nombre sugerido|Para qué sirve|
|---|---|---|
|Sistema operativo instalado y actualizado, con VMware Tools|`00-so-limpio`|Punto de partida común para repetir el laboratorio.|
|Después de la Fase 1|`01-sqlserver-listo`|SQL Server, base `LabSQLi`, tabla y login ya creados.|
|Después de la Fase 2|`02-login-funcional`|Aplicación web funcionando con el login vulnerable.|
|Antes del ataque (Fase 3)|`03-pre-ataque`|Permite repetir el ataque desde un estado limpio.|
|Después de la Fase 5|`05-protegido`|Versión protegida del laboratorio.|

### Buenas prácticas

- Un snapshot **no es una copia de seguridad**: depende del archivo de disco original. Si ese archivo se daña, se pierden los dos.
- Cada snapshot hace crecer los archivos de la VM y puede ralentizarla. Conviene tener pocos y borrar los antiguos que ya no sirvan.
- Con un snapshot tomado con la VM encendida (incluye memoria), al restaurarlo la VM vuelve encendida y en ese mismo punto. Con la VM apagada, el snapshot es más pequeño y limpio.

---

## 7. Instalación de VMware Tools

Con Easy Install, VMware instalaría las herramientas automáticamente. En la instalación manual hay que hacerlo a mano, una vez que Windows está instalado:

1. Con la VM encendida, en el menú de VMware: **VM → Install VMware Tools**.
2. En Windows, abrir la unidad de CD/DVD que aparece y ejecutar el instalador.
3. Reiniciar la VM.

Mejoran la resolución de pantalla, el portapapeles compartido, la integración del ratón y los drivers de dispositivos virtuales. Es buen momento para tomar el snapshot `00-so-limpio`.

---

## 8. Equivalencias en otros hipervisores

El procedimiento manual es válido en cualquier hipervisor. Los nombres cambian:

|Hipervisor|Equivalente a Easy Install|Cómo evitarlo / hacerlo manual|
|---|---|---|
|**VirtualBox**|_Unattended Installation_|Al crear la VM, marcar _Skip Unattended Installation_ (omitir instalación desatendida).|
|**Hyper-V**|_Quick Create_ (disponible sobre todo para algunos sistemas cliente)|Crear la VM con _New → Virtual Machine_ (asistente normal) y asignar la ISO manualmente.|

El tipo de controlador de disco y los nombres exactos de las opciones varían según la versión de cada herramienta, así que conviene revisar la documentación oficial de la versión que se use.

---

## 9. Estado final de la fase

| Elemento                    | Valor                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| --------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Hipervisor                  | [VMware](https://www.vmware.com/)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| Método de instalación       | Manual (sin Easy Install): VM creada sin ISO y ISO agregada después                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| VM servidor                 | Windows Server, [4 CPU](https://techdocs.broadcom.com/es/es/vmware-cis/vsphere/vsphere/9-0/vsphere-virtual-machine-administration/configuring-virtual-machine-hardwarevsphere-vm-admin/virtual-cpu-configuration-and-limitationsvsphere-vm-admin.html), [5 GB RAM](https://techdocs.broadcom.com/es/es/vmware-cis/desktop-hypervisors/workstation-pro/25H2/using-vmware-workstation-player-for-linux-17-0/configuring-and-managing-virtual-machines-linux/change-the-memory-allocation-for-a-virtual-machine-linux.html), disco SCSI de [70 GB](https://cloudian.com/guides/vmware-storage/vmware-storage/) |
| Red                         | NAT                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| Herramientas del hipervisor | VMware Tools instaladas                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| Snapshot de partida         | `00-so-limpio`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |

Siguiente fase: `01-sql-server.md`.