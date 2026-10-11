# no trainer client image

## Build

```bash
podman build -f Containerfile -t ghcr.io/notrainer/no_trainer_client .
```


## Run

```bash
export PASSWORD="$(openssl rand -hex 24)"
export SSH_PASSWORD="$PASSWORD"
podman run -d --name=no_train_client -e CUSTOM_USER=user1 -e PASSWORD -e SSH_PASSWORD -p 127.0.0.1:3000:3000 --shm-size="1gb" ghcr.io/notrainer/no_trainer_client
```

## Nmap-Training

Das Image enthält die Teilnehmerunterlagen, vollständige NSE-Vorlage,
Argumentdateien und Hilfsscripts aus dem aktuellen Nmap-Training unter
[`etc/nmap-training/`](etc/nmap-training/README.md). Sie sind im Container unter
`/opt/nmap-training/` erreichbar; Bind-Mounts aus dem Präsentationsrepository
sind nicht mehr erforderlich. DNS-/Capture-Werkzeuge sowie die optionalen
SMB-/PostgreSQL-Clients werden beim Image-Build installiert.

Beim Start werden fehlende Arbeitskopien für den Desktop-Benutzer in
`~/nmap-training-results/` und `~/http-shop-policy.nse` angelegt. Neustarts und
`setup-training.sh` überschreiben keine vorhandenen Teilnehmerdateien.
Vor einer Neuerstellung des Containers die Ergebnisse weiterhin sichern.

`SCAN_NETWORK` (Standard `172.28.50.0/24`) und ein optionales `SCAN_INTERFACE`
konfigurieren das Übungsnetz. Ohne Interface-Vorgabe wird die direkte Netzroute
verwendet. Neue Desktop-Terminals und SSH-Shells exportieren auch `LAB_IF`,
`LAB_NET`, `LAB_DNS` und `LAB_DOMAIN`. Bei angeschlossenem Übungsnetz setzt der
Start die konkreten mDNS-/SSDP-Routen; dafür `NET_ADMIN` erlauben, für Raw Scans
auch `NET_RAW`. Außerhalb des Labs werden ohne passende Route keine Routen gesetzt.

Die Referenzdateien wurden aus `../presentations/nmap-training/scripts/` und
`../presentations/nmap-training/static/` übernommen. Bei Kursänderungen die
betroffenen Kopien hier aktualisieren und das Image neu bauen. Das gebaute Image
muss vor dem volume-freien Classroom-Start auf dem Trainingshost verfügbar sein.

```bash
python3 tests/check_training.py
```

## SSH access

The Linux account is `abc`; `CUSTOM_USER` configures browser authentication only.
Set `SSH_PASSWORD` to a generated participant password to enable SSH password
login. The image locks the Linux password when `SSH_PASSWORD` is unset and disables
root SSH login.
Mount a separate persistent directory or volume at `/etc/ssh/hostkeys` for each
client. The SSH service creates missing host keys there and reuses them on restart.
Its internal port is 2222. Publish only the intended private host interface and
port when an external reverse NAT rule is configured.

The deployed Nmap lab uses the participant portal password for SSH and publishes
VM ports 2221 through 2227 behind external ports 30001 through 30007.

## Fedora desktop on an AppArmor host

Fedora's Glycin image loaders use Bubblewrap to create a sandbox in an
unprivileged user namespace. Docker's default AppArmor profile denies the mount
operations inside that sandbox. XFCE then crashes repeatedly while loading icons
and can leave large `core.*` files in the participant's home.

The tested host profile is in `deploy/apparmor/nmap-training-client1`. On the
Docker VM, create one copy per client, replacing **every** occurrence of
`nmap-training-client1` with the corresponding client name. Install the copies
under `/etc/apparmor.d/` and load each with `sudo apparmor_parser -r <file>`.
Keep the host's AppArmor service enabled so the profiles load on boot. Use
`deploy/desktop-fix.compose.yml` as an additional override for the seven named
clients. It selects each profile and disables core dumps with a hard limit of 0.
The override also preserves the classroom's tested `seccomp=unconfined` setting.
This does not require privileged containers or `CAP_SYS_ADMIN`.

The image also disables the XFCE graphical PolKit agent: these headless desktops
have no logind session for it to register with. Command-line sudo still works.

The host profile and Compose settings are required deployment configuration;
an image update alone cannot change them. Preserve participant `/config` volumes
and SSH host-key directories when recreating clients. Archive existing crash
files separately before removing them from participant homes.

## Published builds

The master workflow checks the training scripts, then publishes the same image
as `ghcr.io/notrainer/no_trainer_client:latest`, `:master`, and `:<full commit SHA>`.
Use the commit tag (or image digest) in deployments to identify the exact source.
The webtop and Zenmap inputs are pinned to the digests tested in the live lab;
update those pins deliberately when upgrading the base images.
The image carries its source revision as an OCI label.
Manual pages are enabled in the image; the build verifies that `man nmap` renders successfully.

The repository moved to `notrainer/no_trainer_client`. Existing clones should use
`git remote set-url origin git@github.com:notrainer/no_trainer_client.git`.
The old `ghcr.io/b3n4kh/no_trainer_client` package remains available for existing
deployments. Switch their image reference only after the new package is published
and public, or a read-only registry login is configured. The separate
`ghcr.io/b3n4kh/nmap` Zenmap base image remains unchanged.
