# Política de copias de seguridad

| Aspecto | Decisión |
| --- | --- |
| Qué se copia | 3 bases de datos (volcado SQL), volúmenes `joomla_web`, `glpi_datos`, `nextcloud_web`, `kuma_datos` y la configuración (`.env`, certificados, compose) |
| Frecuencia | Diaria a las 02:30 (temporizador systemd `pyme-backup.timer`) y manual antes de cada cambio importante |
| Tipo | Completa en cada ejecución |
| Retención | 7 días (`BACKUP_RETENCION_DIAS`); se borran las carpetas más antiguas |
| Ubicación | `/var/backups/pyme/AAAA-MM-DD_HHMM/`, permisos 700 (solo root). Copia externa recomendada: `rsync` semanal a otro equipo |
| Consistencia | Nextcloud en modo mantenimiento durante la copia; MariaDB con `--single-transaction` |
| Integridad | Fichero `SHA256SUMS` en cada copia; `restore.sh` lo verifica antes de restaurar |
| Restauración | `./scripts/restore.sh <carpeta> <joomla|glpi|nextcloud>`. Objetivo: servicio restaurado en menos de 15 minutos |
| Prueba | Restauración de prueba al menos una vez al mes y en la defensa |
| Responsable | [NOMBRE DEL ALUMNO RESPONSABLE] |
