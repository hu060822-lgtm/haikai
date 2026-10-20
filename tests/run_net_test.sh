#!/usr/bin/env bash
# Runs the two-process multiplayer test on localhost. Usage: tests/run_net_test.sh <godot binary>
set -u
GODOT="${1:-godot}"
cd "$(dirname "$0")/.."
"$GODOT" --headless --path . --script res://tests/net_test.gd -- host > /tmp/haikai_net_host.log 2>&1 &
HOST=$!
sleep 2
"$GODOT" --headless --path . --script res://tests/net_test.gd -- client > /tmp/haikai_net_client.log 2>&1
CLIENT_STATUS=$?
wait $HOST
HOST_STATUS=$?
grep -E "^  (ok|FAIL)|NET TEST|^ERROR" /tmp/haikai_net_host.log | grep -v mesh_get_surface_count
grep -E "^  (ok|FAIL)|NET TEST|^ERROR" /tmp/haikai_net_client.log | grep -v mesh_get_surface_count
[ $HOST_STATUS -eq 0 ] && [ $CLIENT_STATUS -eq 0 ]
