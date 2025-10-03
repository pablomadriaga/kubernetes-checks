# kubernetes-checks

Este es un proyecto temporal para realizar **análisis automatizados en clústeres de Kubernetes**, con el objetivo de verificar configuraciones básicas, detectar problemas comunes y recolectar métricas de salud.  

La herramienta se centra en la simplicidad: a partir de un archivo de definición de clústeres, un script central ejecuta diferentes chequeos y genera resultados en forma de logs.

---



⚙️ Uso

Definir los clústeres en clusters.txt usando el siguiente formato (separado por tabulaciones):
## 🎯 Objetivo

El proyecto busca simplificar la validación de múltiples clústeres de Kubernetes mediante un **script orquestador (`0-runner.sh`)** que ejecuta chequeos predefinidos y guarda los resultados en archivos de log.  

Esto permite detectar rápidamente configuraciones incorrectas o situaciones de riesgo como:  

- Falta de `requests`/`limits` en los pods.  
- PVCs en estado `Pending`.  
- Deployments con pocas réplicas.  
- Pods en namespaces no recomendados (`default`, `kube-system`).  
- Fallas de liveness/readiness.  
- Problemas de nodos o paquetes del sistema.  
- Validaciones básicas de protección de datos.  

## ⚙️Uso

- **Definir los clústeres** en ```clusters.txt``` usando el siguiente formato (separado por tabulaciones):

```text
<cluster_name>   <token>   <certificate>   <ip>
```
Ejemplo
```text
cluster-qa   eyJh...   -----BEGIN CERTIFICATE-----   10.0.0.12
```
- (Opcional) **Agregar clusters a excluir** en exclusiones.txt, uno por línea:
cluster-lab
cluster-dev
```text
cluster-qa   eyJh...   -----BEGIN CERTIFICATE-----   10.0.0.12
```
-**Ejecutar el script principal:**
```bash
./0-runner.sh
```
Esto generará un output en panballa y set de logs dentro de la carpeta ```resultados/```.
## 📊Ejemplo de salida

En consola:
```bash
>>>>> Omitiendo cluster1 (definido en exclusiones.txt)
>>>>> Omitiendo cluster2 (definido en exclusiones.txt)
>>>>> Omitiendo cluster3 (definido en exclusiones.txt)
>>>>> Omitiendo cluster4 (definido en exclusiones.txt)
======Cluster: cluster5 ===========================
===Test de conexión a la API===
===API cluster: cluster5 está OK===
===Cantidad de contenedores sin Requests y Limits===
  ✖ Contenedores sin Requests CPU: 10
  ✖ Contenedores sin Limits CPU: 26
  ✖ Contenedores sin Requests Memoria: 26
  ✖ Contenedores sin Limits Memoria: 26
===Analizando PVs y PVCs no Bound===
  ✔ Todos los PVs están en estado Bound - OK
  ✔ Todos los PVCs están en estado Bound - OK
===Deployments que tienen menos de 2 réplicas===
....
....
===========Cluster: cluster6 ==================================
===Test de conexión a la API===
===API cluster: cluster6 está OK===
===Cantidad de contenedores sin Requests y Limits===
  ✖ Contenedores sin Requests CPU: 1
  ✖ Contenedores sin Limits CPU: 2
  ✖ Contenedores sin Requests Memoria: 1
  ✖ Contenedores sin Limits Memoria: 1
```

