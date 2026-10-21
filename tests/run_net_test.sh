#!/usr/bin/env bash
# Runs the two-process multiplayer test on localhost. Usage: tests/run_net_test.sh <godot binary>
set -u
GODOT="${1:-godot}"
cd "$(dirname "$0")/.."
FAILED=0
# Two scenarios: two scavengers in one squad, and two rival squads.
for PREFIX in "" "pvp-"; do
	"$GODOT" --headless --path . --script res://tests/net_test.gd -- ${PREFIX}host > /tmp/haikai_net_host.log 2>&1 &
	HOST=$!
	sleep 2
	"$GODOT" --headless --path . --script res://tests/net_test.gd -- ${PREFIX}client > /tmp/haikai_net_client.log 2>&1 || FAILED=1
	wait $HOST || FAILED=1
	grep -E "^  (ok|FAIL)|NET TEST|^ERROR" /tmp/haikai_net_host.log | grep -v mesh_get_surface_count
	grep -E "^  (ok|FAIL)|NET TEST|^ERROR" /tmp/haikai_net_client.log | grep -v mesh_get_surface_count
done
[ $FAILED -eq 0 ]
