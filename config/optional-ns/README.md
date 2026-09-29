# Namespaces opcionales por clúster

Crear un archivo `.txt` con el nombre exacto del clúster para indicar qué namespaces pueden no existir en él.

Por ejemplo, para `cluster-qa`:

```text
config/optional-ns/cluster-qa.txt
```

Contenido del archivo, un namespace por línea:

```text
tanzu-system-ingress
```

Si el namespace no existe, se omite el error. Si existe, se ejecutan los chequeos normalmente.
