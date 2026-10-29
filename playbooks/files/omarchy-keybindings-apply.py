#!/usr/bin/env python3
"""Aplica (ou simula) os atalhos escolhidos do Omarchy no GNOME via gsettings.

Chamado por playbooks/user/omarchy-keybindings.yml. Lê JSON do stdin:
  {"items":   [itens escolhidos de files/omarchy-keybindings.vars.yml],
   "scan":    [{schema, ext?}],  # schemas varridos atrás de colisões
   "state":   caminho do JSON com os valores originais,
   "dry_run": bool}
e escreve em stdout um JSON {"changes": [...], "skipped": [...], "warnings": [...]}.

Cada atalho dos itens escolhidos é acrescentado à sua chave e tirado de
qualquer outra chave dos schemas varridos. O valor original de cada chave
tocada fica no arquivo de estado, e o valor desejado é sempre calculado a
partir dele: uma chave que deixa de ser tocada (item desmarcado, ou nenhum
item quando a feature é desligada) volta ao original. O resultado depende
só da seleção, não das execuções anteriores. Idempotente: só grava o que
difere.
"""
import ast
import json
import os
import subprocess
import sys

CUSTOM_SCHEMA = "org.gnome.settings-daemon.plugins.media-keys"
CUSTOM_BASE = "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/"
CUSTOM_REL = CUSTOM_SCHEMA + ".custom-keybinding"
CUSTOM_PREFIX = "omarchy-"
HOME = os.path.expanduser("~")
MODIFIERS = {"ctrl": "control", "primary": "control", "mod1": "alt", "mod4": "super"}


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


def same(a, b):
    """Dois valores GVariant (texto) são iguais."""
    return parse(a) == parse(b)


def norm(accel):
    """'<Ctrl><Super>Q' e '<Super><Control>q' são o mesmo atalho."""
    mods, rest = set(), accel
    while rest.startswith("<") and ">" in rest:
        end = rest.index(">")
        mod = rest[1:end].lower()
        mods.add(MODIFIERS.get(mod, mod))
        rest = rest[end + 1:]
    return frozenset(mods), rest.lower()


def is_accel_list(value):
    return isinstance(value, list) and all(isinstance(a, str) for a in value)


def main():
    req = json.load(sys.stdin)
    dry = req.get("dry_run", False)
    state_path = req["state"]
    changes, skipped, warnings = [], [], []

    originals = {}
    if os.path.exists(state_path):
        with open(state_path) as f:
            originals = json.load(f)

    # Atalhos customizados de apps ausentes ficam de fora (e não reclamam
    # o atalho deles das outras chaves).
    items = []
    for item in req.get("items", []):
        chk = (item.get("custom") or {}).get("check")
        if chk and subprocess.run(["bash", "-c", chk], capture_output=True).returncode != 0:
            skipped.append(f"{item['custom']['name']}: app ausente ({chk})")
            continue
        items.append(item)

    adds, removes, claimed, sets = {}, {}, set(), {}
    for item in items:
        for b in item.get("bind", []):
            k = (b["schema"], b["key"])
            adds.setdefault(k, []).extend(b.get("add", []))
            removes.setdefault(k, set()).update(norm(a) for a in b.get("remove", []))
            claimed.update(norm(a) for a in b.get("add", []))
        for s in item.get("set", []):
            sets[(s["schema"], s["key"])] = s["value"]
        if item.get("custom"):
            claimed.add(norm(item["custom"]["binding"]))

    # Schemas a ler: os varridos, os dos itens e os das chaves a restaurar.
    ext_of = {s["schema"]: s.get("ext") for s in req.get("scan", [])}
    for schema, _ in [*adds, *sets]:
        ext_of.setdefault(schema, None)
    for orig in originals.values():
        ext_of.setdefault(orig["schema"], orig.get("ext"))

    # list-recursively também lista os schemas filhos (org.gnome.mutter traz
    # org.gnome.mutter.keybindings), com o nome de cada um na linha.
    current = {}  # (schema, key) -> texto GVariant atual
    for schema, ext in list(ext_of.items()):
        r = gs(["list-recursively", schema], ext)
        if r.returncode != 0:
            continue
        for line in r.stdout.splitlines():
            found, key, raw = line.split(" ", 2)
            ext_of.setdefault(found, ext)
            current[(found, key)] = raw

    desired = {}  # (schema, key) -> valor (lista ou GVariant literal)
    for (schema, key), raw in current.items():
        if key == "custom-keybindings":
            continue
        base_raw = originals.get(f"{schema} {key}", {}).get("value", raw)
        base = [a for a in parse(base_raw) if a] if is_accel_list(parse(base_raw)) else None
        if base is None:
            continue
        mine = adds.get((schema, key), [])
        mine_norm = {norm(a) for a in mine}
        drop = removes.get((schema, key), set())
        value = [a for a in base
                 if (norm(a) not in claimed or norm(a) in mine_norm) and norm(a) not in drop]
        have = {norm(a) for a in value}
        value += [a for a in mine if norm(a) not in have]
        if value != base:
            desired[(schema, key)] = value
    for k, value in sets.items():
        if k in current:
            desired[k] = value
    for schema, key in [*adds, *sets]:
        if (schema, key) not in current:
            skipped.append(f"{schema} {key}: schema/chave inexistente (extensão não instalada?)")

    def write(schema, key, value):
        r = gs(["set", schema, key, value], ext_of.get(schema))
        if r.returncode != 0:
            raise SystemExit(f"gsettings set {schema} {key} falhou: {r.stderr}")

    for (schema, key), value in desired.items():
        label = f"{schema} {key}"
        cur = current[(schema, key)]
        originals.setdefault(label, {"schema": schema, "key": key,
                                     "ext": ext_of.get(schema), "value": cur})
        if not same(cur, render(value)):
            changes.append({"key": label, "from": cur.strip(), "to": render(value)})
            if not dry:
                write(schema, key, render(value))

    # Chaves que nenhum item escolhido toca mais: de volta ao original (o
    # default, se o original era o default).
    for label, orig in list(originals.items()):
        k = (orig["schema"], orig["key"])
        if k in desired:
            continue
        if k not in current:
            warnings.append(f"{label}: não restaurado (schema ausente); fica para a próxima execução")
            continue
        if not same(current[k], orig["value"]):
            changes.append({"key": label, "from": current[k].strip(), "to": orig["value"].strip() + " (original)"})
            if not dry:
                gs(["reset", *k], orig.get("ext"))
                after = gs(["get", *k], orig.get("ext"))
                if not same(after.stdout, orig["value"]):
                    write(*k, orig["value"])
        del originals[label]

    # Atalhos customizados: os omarchy-* escolhidos; os customN são seus.
    cur = gs(["get", CUSTOM_SCHEMA, "custom-keybindings"])
    existing = parse(cur.stdout) if cur.returncode == 0 else []
    wanted = [i for i in items if i.get("custom")]
    mine = [f"{CUSTOM_BASE}{CUSTOM_PREFIX}{i['id']}/" for i in wanted]
    new_list = [p for p in existing if f"/{CUSTOM_PREFIX}" not in p] + mine
    if new_list != existing:
        changes.append({"key": "custom-keybindings (lista)", "from": cur.stdout.strip(), "to": render(new_list)})
        if not dry:
            write(CUSTOM_SCHEMA, "custom-keybindings", render(new_list))
    for item, path in zip(wanted, mine):
        c = item["custom"]
        schema = f"{CUSTOM_REL}:{path}"
        for k in ("name", "command", "binding"):
            got = gs(["get", schema, k])
            if got.returncode == 0 and parse(got.stdout) == c[k]:
                continue
            changes.append({"key": f"{c['name']} [{k}]", "from": got.stdout.strip(), "to": quote(c[k])})
            if not dry:
                r = gs(["set", schema, k, quote(c[k])])
                if r.returncode != 0:
                    raise SystemExit(f"gsettings set {schema} {k} falhou: {r.stderr}")
    listed = subprocess.run(["dconf", "list", CUSTOM_BASE], text=True, capture_output=True).stdout.split()
    for d in listed:
        path = CUSTOM_BASE + d
        if d.startswith(CUSTOM_PREFIX) and path not in mine:
            changes.append({"key": f"{path} (removido)", "from": "", "to": ""})
            if not dry:
                subprocess.run(["dconf", "reset", "-f", path], check=True)
    for path in existing:
        if f"/{CUSTOM_PREFIX}" in path:
            continue
        got = gs(["get", f"{CUSTOM_REL}:{path}", "binding"])
        binding = parse(got.stdout) if got.returncode == 0 else ""
        if isinstance(binding, str) and binding and norm(binding) in claimed:
            warnings.append(f"seu atalho customizado {path} usa {binding}, que também foi escolhido aqui")

    if not dry:
        if items or originals:
            os.makedirs(os.path.dirname(state_path), exist_ok=True)
            with open(state_path, "w") as f:
                json.dump(originals, f, indent=2, sort_keys=True)
        elif os.path.exists(state_path):
            os.remove(state_path)

    json.dump({"changes": changes, "skipped": skipped, "warnings": warnings}, sys.stdout)


if __name__ == "__main__":
    main()
