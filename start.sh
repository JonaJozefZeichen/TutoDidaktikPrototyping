#!/bin/bash
# Startet das Didaktik-Tool lokal.
#   ./start.sh          baut bei Bedarf, startet den Server, öffnet http://127.0.0.1:8787
#   ./start.sh --dev    mit flutter run auf http://localhost:8788 (r = Hot Reload)
#   ./start.sh --reset  sichert die Testdaten und beginnt neu mit dem Startbestand
set -e
cd "$(dirname "$0")"
WURZEL="$PWD"

MODUS=normal
for arg in "$@"; do
  case "$arg" in
    --dev) MODUS=dev ;;
    --reset)
      if [ -f server/data/bestand.json ]; then
        ZIEL="server/data/sicherung-$(date +%Y%m%d-%H%M%S).json"
        mv server/data/bestand.json "$ZIEL"
        echo "Testdaten gesichert: $ZIEL"
      fi
      ;;
    *) echo "Unbekannte Option: $arg"; exit 1 ;;
  esac
done

if lsof -nP -iTCP:8787 -sTCP:LISTEN >/dev/null 2>&1; then
  echo "Port 8787 ist belegt. Läuft das Tool schon? Sonst den anderen Prozess beenden."
  exit 1
fi

(cd server && dart pub get >/dev/null)

if [ "$MODUS" = normal ]; then
  ZIEL_JS=app/build/web/main.dart.js
  if [ ! -f "$ZIEL_JS" ] || [ -n "$(find app/lib app/assets app/web app/pubspec.yaml packages/didaktik_kern/lib -newer "$ZIEL_JS" -print -quit)" ]; then
    echo "Baue die Web-App, das dauert etwa eine Minute ..."
    (cd app && flutter build web --release --no-web-resources-cdn >/dev/null)
  fi
fi

(cd server && dart run bin/server.dart "$WURZEL") &
SERVER=$!
trap 'kill $SERVER 2>/dev/null || true' EXIT INT TERM

for _ in $(seq 1 60); do
  curl -s -o /dev/null http://127.0.0.1:8787/api/personen && break
  sleep 0.5
done

if [ "$MODUS" = dev ]; then
  (cd app && flutter run -d web-server --web-hostname localhost --web-port 8788)
else
  open http://127.0.0.1:8787
  echo "Läuft auf http://127.0.0.1:8787. Beenden mit Ctrl+C."
  wait $SERVER
fi
