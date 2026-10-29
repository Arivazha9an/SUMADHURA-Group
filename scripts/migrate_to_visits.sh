#!/usr/bin/env bash
# Creates a record in the `visits` resource for every visitor that was saved by
# the old single-visit version of the app (and has no visit yet).
#
#   API_BASE_URL=https://<project-id>.mockapi.io/api/v1 bash scripts/migrate_to_visits.sh
#
# Add --dry-run to only print what would be created. Requires python3.
set -euo pipefail

if [ -z "${API_BASE_URL:-}" ]; then
  echo "Set API_BASE_URL first, e.g. API_BASE_URL=https://<project-id>.mockapi.io/api/v1" >&2
  exit 1
fi

python3 - "$API_BASE_URL" "${1:-}" <<'PY'
import json, sys, urllib.request, urllib.error

base, flag = sys.argv[1].rstrip("/"), sys.argv[2]
dry_run = flag == "--dry-run"

def call(method, path, body=None):
    request = urllib.request.Request(
        base + path,
        data=None if body is None else json.dumps(body).encode(),
        headers={"Content-Type": "application/json"},
        method=method,
    )
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            return json.load(response)
    except urllib.error.URLError as error:
        sys.exit(f"{method} {path} failed: {error}")

visitors = call("GET", "/visitors")
visits = call("GET", "/visits")
has_visit = {str(v.get("visitor_id")) for v in visits}

created = 0
for visitor in visitors:
    vid = str(visitor["id"])
    if vid in has_visit:
        continue
    if not visitor.get("status") or not visitor.get("project"):
        print(f"skip {vid} {visitor.get('name')}: no old visit fields to copy")
        continue
    body = {
        "visitor_id": vid,
        "project": visitor["project"],
        "purpose": visitor.get("purpose") or "",
        "status": visitor["status"],
        "created_at": visitor.get("created_at"),
        "check_in_time": visitor.get("check_in_time"),
        "check_out_time": visitor.get("check_out_time"),
    }
    print(("would create" if dry_run else "creating") + f" visit for {vid} {visitor.get('name')} ({body['status']})")
    if not dry_run:
        call("POST", "/visits", body)
    created += 1

print(f"{created} visit(s) {'to create' if dry_run else 'created'}.")
PY
