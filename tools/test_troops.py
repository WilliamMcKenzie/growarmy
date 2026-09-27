"""Run real troop modules under standalone Luau, with small Roblox API doubles.

Usage: python3 tools/test_troops.py --luau /path/to/luau
No dependencies besides Python and the official Luau CLI tools.
"""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau", default="luau")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    executable = shutil.which(args.luau)
    if executable is None:
        parser.error("Luau CLI not found; supply --luau /path/to/luau")
    compiler = Path(executable).with_name("luau-compile")
    sources = sorted((root / "src").rglob("*.lua"))
    subprocess.run([str(compiler), "--null", *map(str, sources)], check=True)

    # Check that every source module is actually included in the Rojo project.
    mapped = set()

    def visit(node):
        if not isinstance(node, dict):
            return
        if "$path" in node:
            mapped.add(node["$path"])
        for child in node.values():
            visit(child)

    visit(json.loads((root / "default.project.json").read_text()))
    for source in sources:
        assert source.relative_to(root).as_posix() in mapped, f"Unmapped source: {source}"

    # Wrap unmodified production source, resolving Roblox ModuleScripts by name.
    bundle = [(root / "tests/roblox_doubles.luau").read_text()]
    for name, path in (
        ("TroopDefinitions", "src/shared/TroopDefinitions.lua"),
        ("ArmyConfig", "src/shared/ArmyConfig.lua"),
        ("TroopMovement", "src/server/TroopMovement.lua"),
        ("TroopCombat", "src/server/TroopCombat.lua"),
        ("BattleEncounters", "src/server/BattleEncounters.lua"),
        ("TroopWeapons", "src/client/TroopWeapons.lua"),
        ("NeutralSpawns", "src/server/NeutralSpawns.lua"),
        ("NeutralAvatar", "src/server/NeutralAvatar.lua"),
        ("TroopUI", "src/client/TroopUI.lua"),
    ):
        bundle.append(f'modules["{name}"] = (function()\n{(root / path).read_text()}\nend)()')
    bundle.append((root / "tests/troops.luau").read_text())
    with tempfile.TemporaryDirectory(prefix="growarmy-tests-") as directory:
        script = Path(directory) / "troops.luau"
        script.write_text("\n".join(bundle))
        subprocess.run([executable, str(script)], check=True)


if __name__ == "__main__":
    main()
