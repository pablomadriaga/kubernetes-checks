# Excepciones por clúster

El archivo `excepciones.txt` permite configurar excepciones para un clúster sin editar `clusters.ndjson`.

Formato:

```text
cluster;excepcion;valor
```

Se permite una excepción por línea. Las líneas vacías y las líneas que comienzan con `#` se ignoran.

## Excepciones disponibles

### `namespace-opcional`

Permite que un namespace no exista en un clúster. Si el namespace existe, se chequea normalmente.

```text
tmc;namespace-opcional;tanzu-system-ingress
```

### `velero-opcional`

Permite que Velero no esté instalado en un clúster. La ausencia de Velero se informa como advertencia y se omite el chequeo de backups y restores.

```text
tmc;velero-opcional;si
```

Si no se configura esta excepción, la ausencia de Velero se informa como error.

El nombre del clúster debe coincidir exactamente con el campo `name` de `clusters.ndjson`.
