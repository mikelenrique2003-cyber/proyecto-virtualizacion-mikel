# PYME Soluciones — Servicios empresariales virtualizados

Joomla (web) + GLPI (TI) + Nextcloud (documental) en Docker Compose, detrás de un
proxy Nginx con HTTPS. Ampliaciones: copias de seguridad, Uptime Kuma y Fail2ban.

| Nombre | Servicio |
| --- | --- |
| https://www.pyme.lan | Joomla |
| https://soporte.pyme.lan | GLPI |
| https://nube.pyme.lan | Nextcloud |
| https://estado.pyme.lan | Uptime Kuma |

## Requisitos
- VM Ubuntu Server 24.04 LTS (o Debian 12), 4 vCPU, 8 GB RAM, 60 GB disco.
- Un par de claves SSH en tu PC (`ssh-keygen -t ed25519`).

## Puesta en marcha

```bash
# 1. Clonar (como usuario con sudo)
sudo git clone <URL-DEL-REPO> /opt/pyme-servicios
sudo chown -R $USER: /opt/pyme-servicios && cd /opt/pyme-servicios
chmod +x scripts/*.sh

# 2. Preparar el host (actualiza, instala Docker, crea el admin con tu clave)
sudo ./scripts/00-preparar-host.sh adminpyme "$(cat ~/clave.pub)"
#    -> comprueba en OTRA terminal: ssh adminpyme@IP

# 3. Endurecer: UFW, SSH sin contraseña ni root, Fail2ban
sudo ./scripts/01-seguridad.sh adminpyme

# 4. Secretos y certificado (no se suben a Git)
cp .env.example .env && ./scripts/generar-secretos.sh
./scripts/generar-certificado.sh pyme.lan

# 5. Desplegar
docker compose up -d
docker compose ps            # esperar a que todo esté "healthy"/"Up"

# 6. Usuarios y permisos
./scripts/joomla-usuarios.sh
./scripts/nextcloud-config.sh
#    GLPI: ver docs/ o la memoria (se hace desde la web)

# 7. Copias automáticas
sudo cp config/systemd/pyme-backup.* /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable --now pyme-backup.timer

# 8. Pruebas
./scripts/comprobar.sh <IP-de-la-VM>
```

En el PC cliente añade la línea de `config/hosts.example` a tu fichero hosts.

## Operación

| Tarea | Comando |
| --- | --- |
| Ver estado | `docker compose ps` |
| Ver logs de un servicio | `docker compose logs -f glpi` |
| Parar / arrancar uno | `docker compose stop joomla` / `docker compose start joomla` |
| Redesplegar uno | `docker compose up -d --force-recreate nextcloud` |
| Copia manual | `sudo ./scripts/backup.sh` |
| Restaurar | `sudo ./scripts/restore.sh /var/backups/pyme/<fecha> joomla` |

## Estructura

```
docker-compose.yml        servicios, redes y volúmenes
.env.example              plantilla de variables (el .env real NO se sube)
proxy/conf.d/             configuración de Nginx
proxy/certs/              certificado autofirmado (ignorado por Git)
config/                   SSH, Fail2ban, Apache, systemd, hosts
scripts/                  preparación, seguridad, usuarios, copias, pruebas
docs/politica-copias.md   política de copias
```

Si cambias el dominio, cambia `DOMINIO` en `.env` y los `server_name` de `proxy/conf.d/servicios.conf`.
