#!/usr/bin/env python3
"""扫描工作区 pom.xml，解析框架版本；可选合并进 vendor/versions.json 或拉 GitHub 最新版。"""

from __future__ import annotations

import json
import os
import re
import sys
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path

NS = {"m": "http://maven.apache.org/POM/4.0.0"}

FRAMEWORK_GROUPS = {
    "com.easy-query": "easy-query",
    "com.baomidou": "mybatis-plus",
    "com.github.yulichang": "mybatis-plus-join",
}

GITHUB_REPOS = {
    "easy-query": "dromara/easy-query",
    "mybatis-plus": "baomidou/mybatis-plus",
    "mybatis-plus-join": "yulichang/mybatis-plus-join",
}

VERSION_PROPS = {
    "easy-query": ["easy-query.version", "eq.version"],
    "mybatis-plus": ["mybatis-plus.version", "mp.version"],
    "mybatis-plus-join": ["mybatis-plus-join.version", "mpj.version"],
}

SKIP_DIRS = {".git", "target", "node_modules", "vendor", ".cursor"}


def _local(tag: str) -> str:
    return tag.split("}")[-1] if "}" in tag else tag


def _parse_pom(path: Path) -> ET.Element:
    text = path.read_text(encoding="utf-8", errors="ignore")
    text = re.sub(r"xmlns:\w+=\"[^\"]+\"", "", text)
    return ET.fromstring(text)


def _props(root: ET.Element) -> dict[str, str]:
    out: dict[str, str] = {}
    for el in root.findall(".//m:properties/*", NS) + root.findall(".//properties/*"):
        key = _local(el.tag)
        if el.text and el.text.strip():
            out[key] = el.text.strip()
    return out


def _dep_versions(root: ET.Element, props: dict[str, str]) -> dict[str, set[str]]:
    found: dict[str, set[str]] = {k: set() for k in FRAMEWORK_GROUPS.values()}

    def add(group: str | None, version: str | None) -> None:
        if not group or not version:
            return
        fw = FRAMEWORK_GROUPS.get(group)
        if not fw:
            return
        ver = version.strip()
        if ver.startswith("${") and ver.endswith("}"):
            ver = props.get(ver[2:-1], ver)
        if re.match(r"^\d+\.\d+", ver):
            found[fw].add(ver)

    for dep in root.findall(".//m:dependency", NS) + root.findall(".//dependency"):
        g = v = None
        for child in dep:
            name = _local(child.tag)
            if name == "groupId" and child.text:
                g = child.text.strip()
            elif name == "version" and child.text:
                v = child.text.strip()
        add(g, v)

    for dm in root.findall(".//m:dependencyManagement//m:dependency", NS) + root.findall(
        ".//dependencyManagement//dependency"
    ):
        g = v = None
        for child in dm:
            name = _local(child.tag)
            if name == "groupId" and child.text:
                g = child.text.strip()
            elif name == "version" and child.text:
                v = child.text.strip()
        add(g, v)

    return found


def scan_workspace(workspace: Path) -> dict[str, set[str]]:
    merged: dict[str, set[str]] = {k: set() for k in FRAMEWORK_GROUPS.values()}
    if not workspace.is_dir():
        return merged

    for dirpath, dirnames, filenames in os.walk(workspace):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        if "pom.xml" not in filenames:
            continue
        pom = Path(dirpath) / "pom.xml"
        try:
            root = _parse_pom(pom)
            props = _props(root)
            for fw, keys in VERSION_PROPS.items():
                for key in keys:
                    if key in props and re.match(r"^\d+\.\d+", props[key]):
                        merged[fw].add(props[key])
            for fw, vers in _dep_versions(root, props).items():
                merged[fw].update(vers)
        except ET.ParseError:
            continue
    return merged


def fetch_github_latest() -> dict[str, str]:
    latest: dict[str, str] = {}
    for fw, repo in GITHUB_REPOS.items():
        url = f"https://api.github.com/repos/{repo}/releases/latest"
        req = urllib.request.Request(url, headers={"Accept": "application/vnd.github+json"})
        try:
            with urllib.request.urlopen(req, timeout=15) as resp:
                data = json.load(resp)
            tag = (data.get("tag_name") or "").lstrip("v")
            if re.match(r"^\d+\.\d+", tag):
                latest[fw] = tag
        except Exception:
            continue
    return latest


def _semver_key(v: str) -> tuple:
    parts = []
    for p in re.split(r"[.\-]", v):
        if p.isdigit():
            parts.append((0, int(p)))
        else:
            parts.append((1, p))
    return tuple(parts)


def merge_manifest(manifest_path: Path, discovered: dict[str, set[str]], retain: int) -> bool:
    data = json.loads(manifest_path.read_text(encoding="utf-8"))
    changed = False
    for fw, cfg in data.get("frameworks", {}).items():
        new_vers = discovered.get(fw, set())
        if not new_vers:
            continue
        current = list(cfg.get("versions", []))
        merged: list[str] = []
        for v in sorted(new_vers, key=_semver_key, reverse=True):
            if v not in merged:
                merged.append(v)
        for v in current:
            if v not in merged:
                merged.append(v)
        merged = merged[:retain]
        if merged != current:
            cfg["versions"] = merged
            changed = True
    if changed:
        manifest_path.write_text(
            json.dumps(data, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
    return changed


def main() -> int:
    import argparse

    parser = argparse.ArgumentParser(description="Scan pom.xml for framework versions")
    parser.add_argument("--workspace", default=".", help="工作区根目录")
    parser.add_argument("--manifest", required=True, help="vendor/versions.json 路径")
    parser.add_argument("--update-manifest", action="store_true", help="写回 versions.json")
    parser.add_argument("--fallback-github", action="store_true", help="无 pom 时用 GitHub latest")
    parser.add_argument("--retain", type=int, default=3)
    parser.add_argument("--json", action="store_true", help="输出 JSON")
    args = parser.parse_args()

    workspace = Path(args.workspace).resolve()
    manifest = Path(args.manifest).resolve()
    discovered = scan_workspace(workspace)

    has_any = any(discovered.values())
    if not has_any and args.fallback_github:
        gh = fetch_github_latest()
        for fw, ver in gh.items():
            discovered[fw].add(ver)

    if args.update_manifest:
        merge_manifest(manifest, discovered, args.retain)

    if args.json:
        out = {k: sorted(v, key=_semver_key, reverse=True) for k, v in discovered.items()}
        print(json.dumps(out, ensure_ascii=False, indent=2))
    else:
        for fw, vers in discovered.items():
            if vers:
                print(f"{fw}: {', '.join(sorted(vers, key=_semver_key, reverse=True))}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
