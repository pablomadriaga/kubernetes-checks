# Exclusiones de operaciones

El archivo `exclusiones.txt` permite configurar exclusiones de operaciones por clúster sin editar `clusters.ndjson`.

Formato:

```text
cluster;excepcion;valor
```

Se permite una exclusión por línea. Las líneas vacías y las líneas que comienzan con `#` se ignoran.

## Exclusiones disponibles

### `namespace-opcional`

Permite que un namespace no exista en un clúster. Si el namespace existe, se chequea normalmente.

```text
cluster-1;namespace-opcional;namespace-1
```

### `velero-opcional`

Permite que Velero no esté instalado en un clúster. La ausencia de Velero se informa como advertencia y se omite el chequeo de backups y restores.

```text
cluster-1;velero-opcional;si
```

Si no se configura esta exclusión, la ausencia de Velero se informa como error.

El nombre del clúster debe coincidir exactamente con el campo `name` de `clusters.ndjson`.
