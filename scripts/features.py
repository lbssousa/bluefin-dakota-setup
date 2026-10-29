#!/usr/bin/env python3
"""O catálogo de features (features.yml) e as suas escolhas, para as outras ferramentas.

  resolve FASE SAÍDA  grava a seleção resolvida (defaults do catálogo + suas
                      escolhas) como extra vars JSON em SAÍDA e imprime as
                      --tags da FASE: always, cada feature ligada e cada
                      feature desligada que sabe reverter.
                      BLUEFIN_DAKOTA_SETUP_ENABLE (ids separados por espaço)
                      liga features só nesta execução.
  check               o catálogo é consistente, todo id de feature é tag de
                      alguma play (e toda tag de play é uma feature)
  doc                 docs/features.md, gerado a partir do catálogo
  menu ...            dados para scripts/configure.sh (veja menu abaixo)

As escolhas ficam em $XDG_CONFIG_HOME/bluefin-dakota-setup/features.yml:

  features: {<id>: true|false, ...}
"""
import json
import os
import re
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / "features.yml"
CHOICES = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / "bluefin-dakota-setup" / "features.yml"
# Tags que não são features: as plays que rodam sempre.
STRUCTURAL_TAGS = {"always", "never"}


def load_catalog():
    with open(CATALOG) as f:
        return yaml.safe_load(f)


def load_choices():
    if CHOICES.exists():
        with open(CHOICES) as f:
            return yaml.safe_load(f) or {}
    return {}


def resolve(catalog, choices):
    """Defaults do catálogo sobrepostos pelas escolhas."""
    chosen = choices.get("features") or {}
    features = {f["id"]: bool(chosen.get(f["id"], f["default"])) for f in catalog["features"]}
    for f in catalog["features"]:
        if f.get("hidden"):
            features[f["id"]] = True
    return features


def requirement_errors(catalog, features):
    errors = []
    for f in catalog["features"]:
        if not features[f["id"]]:
            continue
        for req in f.get("requires", []):
            if not features.get(req):
                errors.append(f"{f['id']} precisa de {req}")
    return errors


def cmd_resolve(phase, out):
    catalog, choices = load_catalog(), load_choices()
    # `just apply <id>...`: essas features ligadas só nesta execução.
    forced = os.environ.get("BLUEFIN_DAKOTA_SETUP_ENABLE", "").split()
    unknown = [i for i in forced if i not in {f["id"] for f in catalog["features"]}]
    if unknown:
        sys.exit(f"Feature(s) desconhecida(s): {' '.join(unknown)} (veja features.yml)")
    if forced:
        choices = dict(choices)
        choices["features"] = {**(choices.get("features") or {}), **{i: True for i in forced}}
    features = resolve(catalog, choices)
    errors = requirement_errors(catalog, features)
    if errors:
        sys.exit("As escolhas não combinam:\n  " + "\n  ".join(errors) + "\nRode `just configure` para corrigir.")
    Path(out).parent.mkdir(parents=True, exist_ok=True)
    with open(out, "w") as f:
        json.dump({"features_resolved": True, "features": features}, f, indent=2)
    tags = ["always"]
    for f in catalog["features"]:
        if phase not in f["phases"]:
            continue
        if features[f["id"]] or f.get("revert"):
            tags.append(f["id"])
    print(",".join(tags))


def play_tags():
    """Toda tag usada em playbooks/{system,user}/*.yml."""
    tags = {}
    for path in sorted((ROOT / "playbooks").glob("*/*.yml")):
        if path.parent.name == "tasks":
            continue
        for line in path.read_text().splitlines():
            m = re.match(r"^\s*tags:\s*\[(.*)\]", line)
            if m:
                for tag in m.group(1).split(","):
                    tags.setdefault(tag.strip(), set()).add(str(path.relative_to(ROOT)))
    return tags


def cmd_check():
    catalog = load_catalog()
    problems = []
    ids = [f["id"] for f in catalog["features"]]
    groups = catalog["groups"]
    for f in catalog["features"]:
        for key in ("id", "group", "title", "effect", "phases", "default", "revert"):
            if key not in f:
                problems.append(f"feature {f.get('id', '?')}: falta {key}")
        if f.get("group") not in groups:
            problems.append(f"feature {f['id']}: grupo desconhecido {f.get('group')}")
        for phase in f.get("phases", []):
            if phase not in ("system", "user"):
                problems.append(f"feature {f['id']}: fase desconhecida {phase}")
        for req in f.get("requires", []):
            if req not in ids:
                problems.append(f"feature {f['id']}: requisito desconhecido {req}")
    if len(ids) != len(set(ids)):
        problems.append("ids de feature duplicados")
    tags = play_tags()
    for f in catalog["features"]:
        for phase in f.get("phases", []):
            if not any(p.startswith(f"playbooks/{phase}/") for p in tags.get(f["id"], ())):
                problems.append(f"feature {f['id']}: nenhuma play de playbooks/{phase}/ tem essa tag")
    for tag, where in sorted(tags.items()):
        if tag not in ids and tag not in STRUCTURAL_TAGS:
            problems.append(f"tag {tag} ({', '.join(sorted(where))}) não é uma feature de features.yml")
    problems += [f"defaults: {e}" for e in requirement_errors(catalog, resolve(catalog, {}))]
    if problems:
        sys.exit("features.yml:\n  " + "\n  ".join(problems))
    print("Catálogo de features OK.")


def cmd_doc():
    catalog = load_catalog()
    out = [
        "# Features",
        "",
        "<!-- Gerado a partir de features.yml por `just docs`. Não edite à mão. -->",
        "",
        "O que cada automação faz num Bluefin Dakota de fábrica e se vem ligada",
        "até você escolher outra coisa com `just configure`. **Reverte**: desligar",
        "desfaz na próxima execução; senão, desligar só para de gerenciar.",
        "",
    ]
    for group, title in catalog["groups"].items():
        rows = [f for f in catalog["features"] if f["group"] == group and not f.get("hidden")]
        if not rows:
            continue
        out += [f"## {title}", "", "| Feature | Tag | Efeito | Fases | Padrão | Reverte |", "|---|---|---|---|---|---|"]
        for f in rows:
            out.append(
                f"| {f['title']} | `{f['id']}` | {f['effect']} | {', '.join(f['phases'])} | "
                f"{'ligada' if f['default'] else 'desligada'} | {'sim' if f['revert'] else 'não'} |"
            )
        out.append("")
    print("\n".join(out).rstrip() + "\n", end="")


# --- dados para scripts/configure.sh ----------------------------------------
# Linhas separadas por tab; configure.sh as lê com `IFS=$'\t' read`.


def menu_label(text):
    """O --selected do gum choose casa rótulos e separa a lista por vírgulas."""
    return text.replace(", ", " / ").replace(",", " /").replace("|", "/")


def merged_choices(choices, new):
    merged = {"features": dict(choices.get("features") or {})}
    merged["features"].update(new.get("features", {}))
    return merged


def menu(args):
    catalog, choices = load_catalog(), load_choices()
    features = resolve(catalog, choices)
    what = args[0]
    if what == "groups":
        for group, title in catalog["groups"].items():
            if any(f["group"] == group and not f.get("hidden") for f in catalog["features"]):
                print(f"{group}\t{title}")
    elif what == "features":
        admin = args[2] == "1" if len(args) > 2 else True
        for f in catalog["features"]:
            if f["group"] != args[1] or f.get("hidden"):
                continue
            if not admin and "user" not in f["phases"]:
                continue
            mark = " ⟲" if f["revert"] else ""
            print(f"{f['id']}\t{menu_label(f['title'] + mark)}\t{int(features[f['id']])}\t{f['effect']}")
    elif what == "save":
        # stdin: JSON {"features": {...}} (só o que o menu perguntou),
        # mesclado ao arquivo de escolhas.
        merged = merged_choices(choices, json.load(sys.stdin))
        errors = requirement_errors(catalog, resolve(catalog, merged))
        if errors:
            print("\n".join(errors), file=sys.stderr)
            sys.exit(3)
        CHOICES.parent.mkdir(parents=True, exist_ok=True)
        with open(CHOICES, "w") as f:
            f.write("# Gravado por `just configure` (scripts/configure.sh). Catálogo: features.yml.\n")
            yaml.safe_dump(merged, f, sort_keys=True, allow_unicode=True)
    elif what == "summary":
        # stdin: o mesmo JSON do save; imprime o que muda em relação à
        # seleção resolvida atual.
        after = resolve(catalog, merged_choices(choices, json.load(sys.stdin)))
        by_id = {f["id"]: f for f in catalog["features"]}
        for fid, on in after.items():
            if on != features[fid]:
                verb = "ligar" if on else ("reverter" if by_id[fid]["revert"] else "parar de gerenciar")
                print(f"- {verb}: {by_id[fid]['title']}")
    else:
        sys.exit(f"consulta de menu desconhecida: {what}")


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    cmd, args = sys.argv[1], sys.argv[2:]
    if cmd == "resolve" and len(args) == 2:
        cmd_resolve(*args)
    elif cmd == "check":
        cmd_check()
    elif cmd == "doc":
        cmd_doc()
    elif cmd == "menu" and args:
        menu(args)
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
