#!/usr/bin/env python3
"""Turn a Rojo-style src/ tree into one Luau snippet that recreates the scripts inside Studio.

Naming follows Rojo: Name.server.luau -> Script, Name.client.luau -> LocalScript, Name.luau -> ModuleScript.
The first directory under src/ is a service (ReplicatedStorage, ServerScriptService, StarterPlayer, ...).
Top-level project folders (src/<Service>/<Folder>) are wiped and rebuilt, so the installer is idempotent.

usage: make_installer.py <place_dir>   (writes <place_dir>/out/install.luau)
"""
import json
import pathlib
import sys

CLASS_BY_SUFFIX = {".server.luau": "Script", ".client.luau": "LocalScript", ".luau": "ModuleScript"}


def classify(name: str):
    for suffix in (".server.luau", ".client.luau", ".luau"):
        if name.endswith(suffix):
            return name[: -len(suffix)], CLASS_BY_SUFFIX[suffix]
    return None, None


def long_string(source: str) -> str:
    level = 1
    while ("]" + "=" * level + "]") in source:
        level += 1
    eq = "=" * level
    return f"[{eq}[\n{source}]{eq}]"


def main():
    place = pathlib.Path(sys.argv[1]).resolve()
    src = place / "src"
    entries = []
    roots = set()
    for file in sorted(src.rglob("*.luau")):
        rel = file.relative_to(src)
        name, cls = classify(rel.name)
        if not cls:
            continue
        parts = list(rel.parts[:-1])
        service, path = parts[0], parts[1:]
        if service == "StarterPlayer" and path and path[0] in ("StarterPlayerScripts", "StarterCharacterScripts"):
            container, path = path[:1], path[1:]
        else:
            container = []
        if path:
            roots.add((service, tuple(container), path[0]))
        else:
            roots.add((service, tuple(container), name))
        entries.append((service, container + path, name, cls, file.read_text(), str(file.relative_to(place))))

    lines = [
        "local function container(service, path)",
        "\tlocal node = game:GetService(service)",
        "\tfor _, name in path do",
        "\t\tlocal child = node:FindFirstChild(name)",
        "\t\tif not child then",
        "\t\t\tchild = Instance.new('Folder')",
        "\t\t\tchild.Name = name",
        "\t\t\tchild.Parent = node",
        "\t\tend",
        "\t\tnode = child",
        "\tend",
        "\treturn node",
        "end",
        "local created = 0",
        "local function put(service, path, name, className, source)",
        "\tlocal parent = container(service, path)",
        "\tlocal script = Instance.new(className)",
        "\tscript.Name = name",
        "\tscript.Source = source",
        "\tscript.Parent = parent",
        "\tcreated += 1",
        "end",
    ]
    for service, cont, top in sorted(roots):
        cont_lua = "{" + ", ".join(f"'{c}'" for c in cont) + "}"
        lines.append(
            f"do local old = container('{service}', {cont_lua}):FindFirstChild('{top}') if old then old:Destroy() end end"
        )
    for service, path, name, cls, source, _ in entries:
        path_lua = "{" + ", ".join(f"'{p}'" for p in path) + "}"
        lines.append(f"put('{service}', {path_lua}, '{name}', '{cls}', {long_string(source)})")
    lines.append("return 'installed ' .. created .. ' scripts'")

    out = place / "out"
    out.mkdir(exist_ok=True)
    (out / "install.luau").write_text("\n".join(lines) + "\n")
    manifest = {
        "roots": [{"service": s, "container": list(c), "name": t} for s, c, t in sorted(roots)],
        "scripts": [
            {"service": s, "path": p, "name": n, "className": c, "file": f} for s, p, n, c, _, f in entries
        ],
    }
    (out / "manifest.json").write_text(json.dumps(manifest, indent=1))
    print(f"{len(entries)} scripts -> {out / 'install.luau'}")


if __name__ == "__main__":
    main()
