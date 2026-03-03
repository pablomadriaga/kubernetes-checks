# kubernetes-checks

Este es un proyecto temporal para realizar **análisis automatizados en clústeres de Kubernetes**, con el objetivo de verificar configuraciones básicas, detectar problemas comunes y recolectar señales de salud operativa.

La herramienta prioriza la simplicidad y la extensibilidad: a partir de un archivo de definición de clústeres, un **script orquestador (`0-runner.sh`)** ejecuta una serie de chequeos independientes y genera resultados legibles en consola y en archivos de log.

---



## 🎯 Objetivo

El proyecto busca simplificar la validación de múltiples clústeres de Kubernetes mediante un enfoque repetible y automatizado.

Algunos ejemplos de validaciones actuales:

- Falta de `requests` / `limits` en contenedores.
- PVCs en estado `Pending`.
- Deployments con menos de 2 réplicas.
- Pods corriendo en namespaces no recomendados (`default`, control plane).
- Ausencia de `livenessProbe` o `readinessProbe`.
- Problemas de estado de nodos o cercanía al límite de pods.
- Validaciones básicas de protección de datos (backups / restores).
- Estado de paquetes del sistema.

Cada chequeo es un script independiente, lo que facilita su evolución y mantenimiento.

---
## 📁 Arbol de archivos

```Bash
├── 0-runner.sh
├── config
│   ├── clusters.ndjson # "Definición de clusters"
│   ├── exclusiones.txt
│   └── ns # "Namespaces a chequear"
│       ├── customer-ns.txt 
│       ├── packages.txt
│       └── system-ns.txt
├── lib # "Librerias utilizadas en los scripts"
│   ├── api.sh
│   ├── log.sh
│   └── ns.sh
├── profiles # "Modalidad de ejecución de Scripts"
│   ├── daily.list
│   └── weekly.list
├── README.md
├── resultados
│   └── # "Un log por script ejecutado"
└── scripts
    └── # "scripts disponibles"
```

## ⚙️ Definición de clústeres

Los clústeres se definen en un archivo **NDJSON** llamado `clusters.ndjson`, donde **cada línea representa un clúster independiente**.

### 📌 Definición informal de schema v1

- Un objeto NDJSON representa un clúster.
- El clúster es accesible a través de un único endpoint de API.
- La autenticación se realiza mediante **Bearer Token estático**.
- Los campos pueden **extenderse**, pero no modificarse ni eliminarse.
- Cambios estructurales implican una nueva versión de schema.

Esta definición es intencionalmente simple y evolutiva.

---

## Configuración local

Este proyecto requiere archivos locales no versionados:

- ./config/clusters.ndjson
- ./config/exclusiones.txt
- ./profile/$TU_PROFILE.list

Usar como referencia:
- clusters-example.ndjson
- exclusiones-example.txt

---

### 📄 Ejemplo de `clusters.ndjson`

```json
{"schema":1,"name":"cluster-qa","api":{"endpoint":"10.0.0.12","port":6443},"auth":{"token":"eyJh...","ca_cert_b64":"LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t"}}
{"schema":1,"name":"cluster-prod","api":{"endpoint":"10.0.0.15","port":6443},"auth":{"token":"eyJx...","ca_cert_b64":"LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t"}}
```
El formato NDJSON permite extender cada objeto con metadatos adicionales sin romper compatibilidad.

---

## 🚫 Exclusión de clústeres

De forma opcional, se puede definir un archivo `exclusiones.txt` con nombres de clústeres a omitir, uno por línea:

```text
cluster-lab
cluster-dev
```

## 🙋 Profiles
Es la manera de indicar los scripts que se van a ejecutar.

### 📄 daily.list

```text
1-test-api.sh
82-nodes-health.sh
81-system-pods.sh
6-data-protection.sh
8-packages.sh
```

### 📄 weekly.list

```text
*
```

---
## ▶️ Ejecución
Ejecutar el script principal:
```bash
## Por defecto se ejecuta el perfil daily
./0-runner.sh
```
```bash
## Para ejecutar un perfil se escribe su nombre como parametro
./0-runner.sh weekly
```

El script:

- Procesa los clústeres definidos en `clusters.ndjson`.
- Ejecuta los scripts de chequeo en orden.
- Muestra el resultado en consola.
- Guarda logs por chequeo en el directorio `resultados/`.

---

## 📊 Ejemplo de salida
En consola:
```text
===========Cluster: cluster-qa ===============================
===Test de conexión a la API===
===API cluster: cluster-qa está OK===
===Cantidad de contenedores sin Requests y Limits===
  ✖ Contenedores sin Requests CPU: 10
  ✖ Contenedores sin Limits CPU: 26
  ✖ Contenedores sin Requests Memoria: 26
  ✖ Contenedores sin Limits Memoria: 26
===Analizando PVs y PVCs no Bound===
  ✔ Todos los PVs están en estado Bound - OK
  ✔ Todos los PVCs están en estado Bound - OK
===Deployments que tienen menos de 2 réplicas===
...
===========Cluster: cluster-prod =============================
===Test de conexión a la API===
===API cluster: cluster-prod está OK===
===Cantidad de contenedores sin Requests y Limits===
  ✖ Contenedores sin Requests CPU: 1
  ✖ Contenedores sin Limits CPU: 2
```
---
## 🧭 Notas de diseño
- Los scripts de chequeo no asumen estado global.
- Un error en un chequeo no detiene la ejecución completa.
- El proyecto está pensado para evolucionar hacia:
  - enriquecimiento de metadata por clúster,
  - filtrado dinámico,
  - chequeos condicionales basados en capacidades.