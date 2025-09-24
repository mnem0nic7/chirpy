#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
./out &
PID=$!
cleanup() {
  kill "$PID" >/dev/null 2>&1 || true
}
trap cleanup EXIT
sleep 1

printf '\n-- valid --\n'
EMAIL="manual-$(date +%s)@example.com"
PASSWORD="Sup3rSecret!"
USER_RAW=$(curl -s -w '\n%{http_code}' -X POST http://localhost:8080/api/users \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}")
USER_STATUS=${USER_RAW##*$'\n'}
USER_BODY=${USER_RAW%$'\n'$USER_STATUS}
printf 'Status: %s\nBody: %s\n' "$USER_STATUS" "$USER_BODY"
USER_ID=$(USER_BODY_JSON="$USER_BODY" python - <<'PY'
import json, os
data = json.loads(os.environ["USER_BODY_JSON"])
print(data["id"])
PY
)

printf '\n-- login success --\n'
LOGIN_GOOD_RAW=$(curl -s -w '\n%{http_code}' -X POST http://localhost:8080/api/login \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}")
LOGIN_GOOD_STATUS=${LOGIN_GOOD_RAW##*$'\n'}
LOGIN_GOOD_BODY=${LOGIN_GOOD_RAW%$'\n'$LOGIN_GOOD_STATUS}
printf 'Status: %s\nBody: %s\n' "$LOGIN_GOOD_STATUS" "$LOGIN_GOOD_BODY"
AUTH_TOKEN=$(LOGIN_BODY_JSON="$LOGIN_GOOD_BODY" python - <<'PY'
import json, os
data = json.loads(os.environ["LOGIN_BODY_JSON"])
print(data["token"])
PY
)
REFRESH_TOKEN=$(LOGIN_BODY_JSON="$LOGIN_GOOD_BODY" python - <<'PY'
import json, os
data = json.loads(os.environ["LOGIN_BODY_JSON"])
print(data["refresh_token"])
PY
)

printf '\n-- login failure --\n'
LOGIN_BAD_RAW=$(curl -s -w '\n%{http_code}' -X POST http://localhost:8080/api/login \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"$EMAIL\",\"password\":\"wrong\"}")
LOGIN_BAD_STATUS=${LOGIN_BAD_RAW##*$'\n'}
LOGIN_BAD_BODY=${LOGIN_BAD_RAW%$'\n'$LOGIN_BAD_STATUS}
printf 'Status: %s\nBody: %s\n' "$LOGIN_BAD_STATUS" "$LOGIN_BAD_BODY"

printf '\n-- refresh token --\n'
REFRESH_RAW=$(curl -s -w '\n%{http_code}' -X POST http://localhost:8080/api/refresh \
  -H "Authorization: Bearer $REFRESH_TOKEN")
REFRESH_STATUS=${REFRESH_RAW##*$'\n'}
REFRESH_BODY=${REFRESH_RAW%$'\n'$REFRESH_STATUS}
printf 'Status: %s\nBody: %s\n' "$REFRESH_STATUS" "$REFRESH_BODY"
NEW_AUTH_TOKEN=$(REFRESH_BODY_JSON="$REFRESH_BODY" python - <<'PY'
import json, os
data = json.loads(os.environ["REFRESH_BODY_JSON"])
print(data.get("token", ""))
PY
)

printf '\n-- create chirp --\n'
CHIRP_PAYLOAD=$(cat <<EOF
{"body":"Hello, chirpy world!"}
EOF
)
CHIRP_RAW=$(curl -s -w '\n%{http_code}' -X POST http://localhost:8080/api/chirps \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $AUTH_TOKEN" \
  -d "$CHIRP_PAYLOAD")
CHIRP_STATUS=${CHIRP_RAW##*$'\n'}
CHIRP_BODY=${CHIRP_RAW%$'\n'$CHIRP_STATUS}
printf 'Status: %s\nBody: %s\n' "$CHIRP_STATUS" "$CHIRP_BODY"
CHIRP_ID=$(CHIRP_JSON="$CHIRP_BODY" python - <<'PY'
import json, os
data = json.loads(os.environ["CHIRP_JSON"])
print(data["id"])
PY
)

printf '\n-- chirp too long --\n'
LONG_TEXT=$(python - <<'PY'
import sys
sys.stdout.write("A" * 150)
PY
)
LONG_PAYLOAD=$(cat <<EOF
{"body":"$LONG_TEXT"}
EOF
)
LONG_RAW=$(curl -s -w '\n%{http_code}' -X POST http://localhost:8080/api/chirps \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $AUTH_TOKEN" \
  -d "$LONG_PAYLOAD")
LONG_STATUS=${LONG_RAW##*$'\n'}
LONG_BODY_RESP=${LONG_RAW%$'\n'$LONG_STATUS}
printf 'Status: %s\nBody: %s\n' "$LONG_STATUS" "$LONG_BODY_RESP"

printf '\n-- invalid json --\n'
curl -s -i -X POST http://localhost:8080/api/chirps \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $AUTH_TOKEN" \
  -d '{bad json}' || true

printf '\n-- profane chirp sanitization --\n'
PROFANE_PAYLOAD=$(cat <<EOF
{"body":"kerfuffle sharbert fornax"}
EOF
)
PROFANE_RAW=$(curl -s -w '\n%{http_code}' -X POST http://localhost:8080/api/chirps \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $AUTH_TOKEN" \
  -d "$PROFANE_PAYLOAD")
PROFANE_STATUS=${PROFANE_RAW##*$'\n'}
PROFANE_BODY=${PROFANE_RAW%$'\n'$PROFANE_STATUS}
printf 'Status: %s\nBody: %s\n' "$PROFANE_STATUS" "$PROFANE_BODY"

printf '\n-- revoke refresh token --\n'
REVOKE_STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X POST http://localhost:8080/api/revoke \
  -H "Authorization: Bearer $REFRESH_TOKEN")
printf 'Status: %s\n' "$REVOKE_STATUS"

printf '\n-- refresh after revoke --\n'
POST_REVOKE_RAW=$(curl -s -w '\n%{http_code}' -X POST http://localhost:8080/api/refresh \
  -H "Authorization: Bearer $REFRESH_TOKEN")
POST_REVOKE_STATUS=${POST_REVOKE_RAW##*$'\n'}
POST_REVOKE_BODY=${POST_REVOKE_RAW%$'\n'$POST_REVOKE_STATUS}
printf 'Status: %s\nBody: %s\n' "$POST_REVOKE_STATUS" "$POST_REVOKE_BODY"

printf '\n-- get chirp by id --\n'
SINGLE_RAW=$(curl -s -w '\n%{http_code}' http://localhost:8080/api/chirps/$CHIRP_ID)
SINGLE_STATUS=${SINGLE_RAW##*$'\n'}
SINGLE_BODY=${SINGLE_RAW%$'\n'$SINGLE_STATUS}
printf 'Status: %s\nBody: %s\n' "$SINGLE_STATUS" "$SINGLE_BODY"

printf '\n-- list chirps --\n'
LIST_RAW=$(curl -s -w '\n%{http_code}' http://localhost:8080/api/chirps)
LIST_STATUS=${LIST_RAW##*$'\n'}
LIST_BODY=${LIST_RAW%$'\n'$LIST_STATUS}
printf 'Status: %s\nBody: %s\n' "$LIST_STATUS" "$LIST_BODY"
