#!/usr/bin/env bash
# Posts the sample records in api/seed_visitors.json to your mock API so the
# dashboard and list have something to show. For every person it creates one
# record in `visitors` (identity) and one or more records in `visits`.
# A record may list "previous_visits" (finished sessions) to demo repeat visits.
#
#   API_BASE_URL=https://<project-id>.mockapi.io/api/v1 bash scripts/seed_api.sh
#
# Both resources, `visitors` and `visits`, must exist in your MockAPI project
# first (see README). Timestamps are rewritten relative to "now" so the
# dashboard's "today" figures are non-zero. Requires curl and python3.
set -euo pipefail

if [ -z "${API_BASE_URL:-}" ]; then
  echo "Set API_BASE_URL first, e.g. API_BASE_URL=https://<project-id>.mockapi.io/api/v1" >&2
  exit 1
fi

SEED_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/api/seed_visitors.json"

python3 - "$SEED_FILE" "$API_BASE_URL" <<'PY'
import json, sys, urllib.request, urllib.error
from datetime import datetime, timedelta

seed_path, base = sys.argv[1], sys.argv[2].rstrip("/")
now = datetime.now().astimezone().replace(microsecond=0)

def stamp(minutes_ago):
    return None if minutes_ago is None else (now - timedelta(minutes=minutes_ago)).isoformat()

def post(path, body):
    request = urllib.request.Request(
        base + path,
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            return json.load(response)
    except urllib.error.URLError as error:
        sys.exit(f"Request to {path} failed: {error}")

for record in json.load(open(seed_path, encoding="utf-8")):
    sessions = list(record.get("previous_visits", [])) + [record]
    first_created = max(s["created_minutes_ago"] for s in sessions)
    visitor = post("/visitors", {
        "name": record["name"],
        "mobile": record["mobile"],
        "email": record["email"],
        "visitor_type": record["visitor_type"],
        "created_at": stamp(first_created),
    })
    for session in sessions:
        post("/visits", {
            "visitor_id": str(visitor["id"]),
            "project": session["project"],
            "purpose": session["purpose"],
            "status": session.get("status", "Checked Out"),
            "created_at": stamp(session["created_minutes_ago"]),
            "check_in_time": stamp(session["check_in_minutes_ago"]),
            "check_out_time": stamp(session["check_out_minutes_ago"]),
        })
    print(f"created visitor id={visitor.get('id')} {record['name']} with {len(sessions)} visit(s)")
PY
