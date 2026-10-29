#!/usr/bin/env python3
"""Aplica (ou simula) os atalhos do Omarchy no GNOME via gsettings.

Chamado por playbooks/user/omarchy-keybindings.yml. Lê JSON do stdin:
  {"settings": [{schema, key, value, ext?}],
   "custom":   [{id, name, binding, command, check?}],
   "dry_run":  bool}
e escreve em stdout um JSON {"changes": [...], "skipped": [...]}.
Idempotente: só chama `gsettings set` quando o valor atual difere.
"""
import ast
import glob
import json
import os
import subprocess
import sys

CUSTOM_SCHEMA = "org.gnome.settings-daemon.plugins.media-keys"
CUSTOM_BASE = "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/"
CUSTOM_REL = CUSTOM_SCHEMA + ".custom-keybinding"
HOME = os.path.expanduser("~")


def env_for(ext):
    env = dict(os.environ)
    if ext:
        for d in (f"{HOME}/.local/share/gnome-shell/extensions/{ext}/schemas",
                  f"/usr/share/gnome-shell/extensions/{ext}/schemas"):
            if os.path.isdir(d):
                env["GSETTINGS_SCHEMA_DIR"] = d
                break
    return env


def gs(args, ext=None):
    return subprocess.run(["gsettings", *args], env=env_for(ext), text=True,
                          capture_output=True)


def quote(s):
    return "'" + s.replace("\\", "\\\\").replace("'", "\\'") + "'"


def render(value):
    if isinstance(value, list):
        return "[" + ", ".join(quote(v) for v in value) + "]" if value else "@as []"
    return value


def parse(out):
    out = out.strip()
    if out.startswith("@as "):
        out = out[4:]
    try:
        return ast.literal_eval(out)
    except (ValueError, SyntaxError):
        return out


def same(cur_out, value):
    cur = parse(cur_out)
    return cur == value if isinstance(value, list) else cur_out.strip() == value


def main():
    req = json.load(sys.stdin)
    dry = req.get("dry_run", False)
    changes, skipped = [], []

    def ensure(schema, key, value, ext=None, label=None):
        label = label or f"{schema} {key}"
        cur = gs(["get", schema, key], ext)
        if cur.returncode != 0:
            skipped.append(f"{label}: schema/chave inexistente")
            return
        if same(cur.stdout, value):
            return
        changes.append({"key": label, "from": cur.stdout.strip(), "to": render(value)})
        if not dry:
            r = gs(["set", schema, key, render(value)], ext)
            if r.returncode != 0:
                raise SystemExit(f"gsettings set {label} falhou: {r.stderr}")

    for s in req.get("settings", []):
        ensure(s["schema"], s["key"], s["value"], s.get("ext"))

    wanted = []
    for c in req.get("custom", []):
        chk = c.get("check")
        if chk and subprocess.run(["bash", "-c", chk], capture_output=True).returncode != 0:
            skipped.append(f"{c['name']}: app ausente ({chk})")
            continue
        wanted.append(c)

    cur = gs(["get", CUSTOM_SCHEMA, "custom-keybindings"])
    existing = parse(cur.stdout) if cur.returncode == 0 else []
    mine = [CUSTOM_BASE + f"omarchy-{c['id']}/" for c in wanted]
    new_list = [p for p in existing if "/omarchy-" not in p] + mine
    if new_list != existing:
        ensure(CUSTOM_SCHEMA, "custom-keybindings", new_list, label="custom-keybindings (lista)")
    for c, path in zip(wanted, mine):
        schema = f"{CUSTOM_REL}:{path}"
        for k in ("name", "command", "binding"):
            cur = gs(["get", schema, k])
            want = quote(c[k])
            if cur.returncode == 0 and parse(cur.stdout) == c[k]:
                continue
            changes.append({"key": f"{c['name']} [{k}]", "from": cur.stdout.strip(), "to": want})
            if not dry:
                r = gs(["set", schema, k, want])
                if r.returncode != 0:
                    raise SystemExit(f"gsettings set {schema} {k} falhou: {r.stderr}")

    json.dump({"changes": changes, "skipped": skipped}, sys.stdout)


if __name__ == "__main__":
    main()
