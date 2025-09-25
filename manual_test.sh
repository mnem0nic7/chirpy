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

POLKA_KEY=$(grep -E '^POLKA_KEY=' .env | cut -d= -f2- | tr -d '"')

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

printf '\n-- update user --\n'
NEW_EMAIL="updated-$EMAIL"
NEW_PASSWORD="N3wSup3rSecret!"
UPDATE_RAW=$(curl -s -w '\n%{http_code}' -X PUT http://localhost:8080/api/users \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $AUTH_TOKEN" \
  -d "{\"email\":\"$NEW_EMAIL\",\"password\":\"$NEW_PASSWORD\"}")
UPDATE_STATUS=${UPDATE_RAW##*$'\n'}
UPDATE_BODY=${UPDATE_RAW%$'\n'$UPDATE_STATUS}
printf 'Status: %s\nBody: %s\n' "$UPDATE_STATUS" "$UPDATE_BODY"

printf '\n-- login with updated credentials --\n'
EMAIL="$NEW_EMAIL"
PASSWORD="$NEW_PASSWORD"
LOGIN_UPDATED_RAW=$(curl -s -w '\n%{http_code}' -X POST http://localhost:8080/api/login \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}")
LOGIN_UPDATED_STATUS=${LOGIN_UPDATED_RAW##*$'\n'}
LOGIN_UPDATED_BODY=${LOGIN_UPDATED_RAW%$'\n'$LOGIN_UPDATED_STATUS}
printf 'Status: %s\nBody: %s\n' "$LOGIN_UPDATED_STATUS" "$LOGIN_UPDATED_BODY"
AUTH_TOKEN=$(LOGIN_BODY_JSON="$LOGIN_UPDATED_BODY" python - <<'PY'
import json, os
data = json.loads(os.environ["LOGIN_BODY_JSON"])
print(data.get("token", ""))
PY
)
REFRESH_TOKEN=$(LOGIN_BODY_JSON="$LOGIN_UPDATED_BODY" python - <<'PY'
import json, os
data = json.loads(os.environ["LOGIN_BODY_JSON"])
print(data.get("refresh_token", ""))
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
PROFANE_ID=$(PROFANE_JSON="$PROFANE_BODY" python - <<'PY'
import json, os
data = json.loads(os.environ["PROFANE_JSON"])
print(data.get("id", ""))
PY
)

printf '\n-- create chirp to delete --\n'
DELETE_CHIRP_PAYLOAD=$(cat <<EOF
{"body":"This chirp will vanish."}
EOF
)
DELETE_CHIRP_RAW=$(curl -s -w '\n%{http_code}' -X POST http://localhost:8080/api/chirps \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $AUTH_TOKEN" \
  -d "$DELETE_CHIRP_PAYLOAD")
DELETE_CHIRP_STATUS=${DELETE_CHIRP_RAW##*$'\n'}
DELETE_CHIRP_BODY=${DELETE_CHIRP_RAW%$'\n'$DELETE_CHIRP_STATUS}
printf 'Status: %s\nBody: %s\n' "$DELETE_CHIRP_STATUS" "$DELETE_CHIRP_BODY"
DELETE_CHIRP_ID=$(DELETE_CHIRP_JSON="$DELETE_CHIRP_BODY" python - <<'PY'
import json, os
data = json.loads(os.environ["DELETE_CHIRP_JSON"])
print(data.get("id", ""))
PY
)

printf '\n-- delete chirp --\n'
DELETE_STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X DELETE http://localhost:8080/api/chirps/$DELETE_CHIRP_ID \
  -H "Authorization: Bearer $AUTH_TOKEN")
printf 'Status: %s\n' "$DELETE_STATUS"

printf '\n-- get deleted chirp --\n'
DELETED_RAW=$(curl -s -w '\n%{http_code}' http://localhost:8080/api/chirps/$DELETE_CHIRP_ID)
DELETED_STATUS=${DELETED_RAW##*$'\n'}
DELETED_BODY=${DELETED_RAW%$'\n'$DELETED_STATUS}
printf 'Status: %s\nBody: %s\n' "$DELETED_STATUS" "$DELETED_BODY"

printf '\n-- polka webhook user.upgraded --\n'
WEBHOOK_PAYLOAD=$(cat <<EOF
{
  "event": "user.upgraded",
  "data": {
    "user_id": "$USER_ID"
  }
}
EOF
)
WEBHOOK_STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X POST http://localhost:8080/api/polka/webhooks \
  -H 'Content-Type: application/json' \
  -H "Authorization: ApiKey $POLKA_KEY" \
  -d "$WEBHOOK_PAYLOAD")
printf 'Status: %s\n' "$WEBHOOK_STATUS"

printf '\n-- login after upgrade --\n'
UPGRADED_LOGIN_RAW=$(curl -s -w '\n%{http_code}' -X POST http://localhost:8080/api/login \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}")
UPGRADED_LOGIN_STATUS=${UPGRADED_LOGIN_RAW##*$'\n'}
UPGRADED_LOGIN_BODY=${UPGRADED_LOGIN_RAW%$'\n'$UPGRADED_LOGIN_STATUS}
printf 'Status: %s\nBody: %s\n' "$UPGRADED_LOGIN_STATUS" "$UPGRADED_LOGIN_BODY"

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

printf '\n-- list chirps by author asc --\n'
LIST_AUTHOR_ASC_RAW=$(curl -s -w '\n%{http_code}' "http://localhost:8080/api/chirps?author_id=$USER_ID&sort=asc")
LIST_AUTHOR_ASC_STATUS=${LIST_AUTHOR_ASC_RAW##*$'\n'}
LIST_AUTHOR_ASC_BODY=${LIST_AUTHOR_ASC_RAW%$'\n'$LIST_AUTHOR_ASC_STATUS}
printf 'Status: %s\nBody: %s\n' "$LIST_AUTHOR_ASC_STATUS" "$LIST_AUTHOR_ASC_BODY"
ASC_FIRST_ID=$(LIST_AUTHOR_ASC_BODY_JSON="$LIST_AUTHOR_ASC_BODY" python - <<'PY'
import json, os, sys
data = json.loads(os.environ["LIST_AUTHOR_ASC_BODY_JSON"])
if not data:
    sys.exit("expected chirps for asc sort")
print(data[0]["id"])
PY
)
if [[ "$ASC_FIRST_ID" != "$CHIRP_ID" ]]; then
  echo "unexpected first chirp id for asc sort: $ASC_FIRST_ID"
  exit 1
fi

printf '\n-- list chirps by author desc --\n'
LIST_AUTHOR_DESC_RAW=$(curl -s -w '\n%{http_code}' "http://localhost:8080/api/chirps?author_id=$USER_ID&sort=desc")
LIST_AUTHOR_DESC_STATUS=${LIST_AUTHOR_DESC_RAW##*$'\n'}
LIST_AUTHOR_DESC_BODY=${LIST_AUTHOR_DESC_RAW%$'\n'$LIST_AUTHOR_DESC_STATUS}
printf 'Status: %s\nBody: %s\n' "$LIST_AUTHOR_DESC_STATUS" "$LIST_AUTHOR_DESC_BODY"
DESC_FIRST_ID=$(LIST_AUTHOR_DESC_BODY_JSON="$LIST_AUTHOR_DESC_BODY" python - <<'PY'
import json, os, sys
data = json.loads(os.environ["LIST_AUTHOR_DESC_BODY_JSON"])
if not data:
    sys.exit("expected chirps for desc sort")
print(data[0]["id"])
PY
)
if [[ "$DESC_FIRST_ID" != "$PROFANE_ID" ]]; then
  echo "unexpected first chirp id for desc sort: $DESC_FIRST_ID"
  exit 1
fi
