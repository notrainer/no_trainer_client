# Nmap-Training im Client

Die Referenzen liegen in `/opt/nmap-training/` (Verweis auf `/etc/nmap-training`).
Beim Containerstart werden fehlende Arbeitskopien in `~/nmap-training-results/`
und `~/http-shop-policy.nse` angelegt. Vorhandene Dateien bleiben erhalten.
Alles darf weiterhin von Hand angelegt oder in der Arbeitskopie verändert werden.
Die Referenzdateien gehören root; zum Bearbeiten die persönlichen Kopien verwenden.

```bash
cd ~/nmap-training-results
printf 'Interface: %s\nNetz: %s\nDNS: %s\n' "$LAB_IF" "$SCAN_NETWORK" "$LAB_DNS"
ip -br address
ip route get 224.0.0.251
ip route get 239.255.255.250
```

| Variable | Vorgabe / Bedeutung |
| --- | --- |
| `SCAN_NETWORK`, `LAB_NET` | `172.28.50.0/24`, internes Übungsnetz |
| `SCAN_INTERFACE`, `LAB_IF` | Schnittstelle aus der direkten Route ins Übungsnetz |
| `LAB_DNS` | `172.28.50.10`, expliziter DNS-Server für `dig` |
| `LAB_DOMAIN` | `shop.test`, DNS-Zone |
| `NMAP_TRAINING` | `/opt/nmap-training`, Referenzverzeichnis |
| `NMAP_SAGE_API_KEY` | Eigener API-Key aus dem Deployment; leer deaktiviert Nmap Sage |

Compose setzt die Vorgaben für alle sieben Clients. Docker-Umgebungsvariablen
werden auch in neuen Desktop-Terminals und SSH-Shells geladen. Ein leeres
`SCAN_INTERFACE` aktiviert die Erkennung; ein expliziter Wert überschreibt sie.
Das Profil setzt keine Nmap-Optionen automatisch: `-e "$LAB_IF"` oder
`"$SCAN_NETWORK"` weiter ausdrücklich angeben.

```bash
# Interface bei Bedarf manuell setzen und die beiden Lab-Routen neu vorbereiten:
export SCAN_INTERFACE=eth1  # Tatsächlichen Namen aus ip -br address verwenden.
. /etc/profile.d/nmap-training.sh
sudo env SCAN_INTERFACE="$SCAN_INTERFACE" /opt/nmap-training/scripts/multicast-routes.sh

# Fehlende Arbeitskopien erneut anlegen, ohne bestehende Dateien zu überschreiben:
/opt/nmap-training/scripts/setup-training.sh
```

| Datei | Übung / Verwendung |
| --- | --- |
| `handouts/*` | Ziel-/DNS-Listen, Protokollblatt und fiktive Inventar-/Traffic-Daten |
| `examples/excluded.txt` | D1.1: `.40` aus einer Inputliste ausschließen |
| `examples/hello.lua` | D2.5: erste Ausgabe, CLI-Argument und Default |
| `examples/status-check.lua` | D2.5: Function, Zahlenumwandlung und Statusvergleich |
| `examples/inventory.lua` | D2.5: Tables, Schleife und Review-Zähler mit Lehrdaten |
| `examples/http.args` | D2.4: HTTP-GET auf `/maintenance/` |
| `examples/dns-brute.args` | D2.2: kleine DNS-Kandidatenliste |
| `examples/ldap.args` | D2.4-F: begrenzte Suche mit öffentlichen Lab-Zugangsdaten |
| `scripts/http-shop-policy.nse` | D3.3: vollständige NSE-Vorlage |
| `scripts/read-nmap-xml.py` | D2.4: Script-ID und lesbaren Output aus XML auslesen |
| `scripts/web-baseline.sh` | D1.4 / D3.2: identischer Scan der beiden Webziele |
| `scripts/compare-scans.sh` | D3.2: Textvergleich; Exit 1 bedeutet Unterschiede |
| `scripts/capture-discovery.sh` | D3.1: auf 60 Sekunden begrenzter Capture |
| `handouts/wireshark-day3.txt` | D3: Wireshark-Streams, Graphs, IPv6/NDP, DNS und TLS |
| `scripts/multicast-routes.sh` | D2.3: mDNS-/SSDP-Routen im Client, beim Start vorbereitet |

Die Shell-/Python-Hilfen liegen zusätzlich als bearbeitbare Kopien im Ergebnisordner.
Beispielaufrufe dort:

```bash
./web-baseline.sh day1-web-before
lua hello.lua Ada
lua status-check.lua 200
lua status-check.lua 401
lua inventory.lua
nmap -n -sL -iL targets.txt --excludefile excluded.txt
nmap -n -sT -p 80 --script http-headers --script-args-file http.args \
  --script-timeout 20s appliance appliance-managed -oA d2-http-repeat
./read-nmap-xml.py d2-http-repeat.xml
nmap --dns-servers "$LAB_DNS" --script dns-brute --script-args-file dns-brute.args \
  --script-timeout 15s -oN d2-dns-candidates.nmap
sudo ./capture-discovery.sh day3-discovery.pcapng
./web-baseline.sh day3-web-control
# Nach der durch den Trainer koordinierten Dienstunterbrechung:
./web-baseline.sh day3-web-after
./compare-scans.sh day3-web-control.nmap day3-web-after.nmap
nmap -n -sT -sV -p 80 --script ~/http-shop-policy.nse appliance appliance-managed
```

Scans und Captures starten ausschließlich mit einem manuellen Aufruf.
Lua-Referenzen verwenden feste Lehrdaten und erzeugen keinen Netzwerkverkehr.
Für den Einstieg zuerst eigene `my-*.lua`-Dateien tippen; danach die Referenzen
vergleichen. `lua` führt sie aus, `luac -p my-hello.lua` prüft nur die Syntax.
NSE-Scripts laufen dagegen mit `nmap` und dessen integrierter Lua-Laufzeit.

Die Einrichtung setzt nur die zwei konkreten Multicast-Routen und kopiert Referenzen.
`switch-ports.csv` und `traffic-summary.csv` enthalten ausdrücklich fiktive Daten.
Trainerlösungen aus `tasks.txt` werden nicht ins Image kopiert.

## Tag 3 mit Wireshark

Die Arbeitskarte `~/nmap-training-results/wireshark-day3.txt` enthält Capture-
und Display Filter, Commands, Dateinamen und Abgaben. Wireshark als `abc` starten;
die Gruppe `wireshark` erlaubt Capture über `dumpcap`. Keine GUI mit sudo starten.
Bei fehlenden Interfaces `id` und `dumpcap -D` durch den Trainer prüfen lassen;
alternativ mit `tshark` erfassen und danach die Datei in der GUI öffnen.

Die neue Kurs-Compose stellt die bestehende `nmap`-Bridge auf Dual Stack um.
Dieselbe `appliance` besitzt dann `172.28.50.20` und `fd28:50::20`; Docker-DNS
liefert A/AAAA für `appliance`. Der Lab-DNS kennt auch `appliance.shop.test` und
den Kurznamen mit beiden Adressen. `curl appliance` wählt selbst, `curl -4 appliance`
und `curl -6 appliance` erzwingen IPv4/IPv6. `LAB_IF` ist für beide Familien dieselbe
Schnittstelle. Die Bridge muss im Wartungsfenster neu erstellt werden; ein
Client-Image-Update allein aktiviert Dual Stack nicht.

Vorhandene Arbeitskopien bleiben erhalten. Falls die neue Karte fehlt, nach dem
Image-Update `/opt/nmap-training/scripts/setup-training.sh` ausführen. Alternativ
die Kursdatei `static/wireshark-day3.txt` in den eigenen Ergebnisordner kopieren.

## Nmap Sage

`nmap-sage` ist im Suchpfad und als `~/nmap-sage` verfügbar. Vorhandene Dateien
oder Links werden beim Start nicht ersetzt. Neue Desktop-Terminals und
SSH-Shells laden den eigenen API-Key aus der Container-Umgebung.

```bash
./nmap-sage how can I find vulnerabilities in vsftpd
nmap-sage "Was bedeutet filtered in Nmap?"
```

Die Anfrage geht an `https://llm.nmap.b3n.eu/v1/chat/completions`. Die Antwort
enthält einen Nmap-Befehl oder einen sehr kurzen Satz. `TARGET` bei Bedarf
ersetzen. Das Script führt nichts aus und speichert keinen Gesprächsverlauf.
Ohne `NMAP_SAGE_API_KEY` erklärt es, dass der Trainer den Dienst aktivieren muss.
Der Server prüft das Thema, begrenzt Anfragen und lehnt Fragen außerhalb von
Nmap ab. Den OpenRouter-Key niemals im Client setzen.
