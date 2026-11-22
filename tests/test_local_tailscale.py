import json
import re

TAILSCALE = "/opt/homebrew/bin/tailscale"
SOCKET = "--socket=/var/run/tailscaled.socket"
SERVICE = "system/sh.brew.tailscale"
PLIST = "/Library/LaunchDaemons/sh.brew.tailscale.plist"


def test_tailscale_binary_exists(host):
    assert host.file(TAILSCALE).exists


def test_launchd_service_running(host):
    result = host.run(f"launchctl print {SERVICE}")
    assert result.rc == 0, result.stderr
    assert re.search(r"^\s*state = running\s*$", result.stdout, re.M)


def test_run_at_load_enabled(host):
    result = host.run(f"/usr/libexec/PlistBuddy -c 'Print :RunAtLoad' {PLIST}")
    assert result.rc == 0, result.stderr
    assert result.stdout.strip() == "true"


def test_backend_state_running(host):
    result = host.run(f"{TAILSCALE} {SOCKET} status --json")
    assert result.rc == 0, result.stderr
    assert json.loads(result.stdout)["BackendState"] == "Running"


def test_tailscale_ssh_enabled(host):
    result = host.run(f"{TAILSCALE} {SOCKET} debug prefs")
    assert result.rc == 0, result.stderr
    assert json.loads(result.stdout)["RunSSH"] is True


def test_service_not_disabled(host):
    result = host.run("launchctl print-disabled system")
    assert result.rc == 0, result.stderr
    assert '"sh.brew.tailscale" => disabled' not in result.stdout
