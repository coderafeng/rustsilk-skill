#!/usr/bin/env bash
# 从 Maven Central 下载 *-sources.jar 并解压到 vendor/<framework>/<version>/
#
# 用法:
#   ./scripts/sync-vendor-sources.sh
#       按 vendor/versions.json 全量同步
#
#   ./scripts/sync-vendor-sources.sh --scan-pom /path/to/your-java-project --update-manifest
#       扫描工作区所有 pom.xml，合并版本到 versions.json 再同步
#
#   ./scripts/sync-vendor-sources.sh --scan-pom . --update-manifest --fallback-github
#       无 pom 时从 GitHub Releases 取最新版写入 versions.json
#
#   ./scripts/sync-vendor-sources.sh --framework easy-query --version 3.2.7 --no-prune
#   ./scripts/sync-vendor-sources.sh --with-git-tests
#   ./scripts/sync-vendor-sources.sh --profile springBoot4

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST="$ROOT/vendor/versions.json"
CACHE="$ROOT/vendor/.cache"
SCAN_POM=""
UPDATE_MANIFEST=false
FALLBACK_GITHUB=false
WITH_GIT_TESTS=false
ONLY_FRAMEWORK=""
ONLY_VERSION=""
NO_PRUNE=false
ARTIFACT_PROFILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-git-tests) WITH_GIT_TESTS=true; shift ;;
    --framework)
      ONLY_FRAMEWORK="${2:-}"
      shift 2
      ;;
    --version)
      ONLY_VERSION="${2:-}"
      shift 2
      ;;
    --no-prune) NO_PRUNE=true; shift ;;
    --scan-pom)
      if [[ $# -ge 2 && "$2" != --* ]]; then
        SCAN_POM="$2"
        shift 2
      else
        SCAN_POM="."
        shift
      fi
      ;;
    --update-manifest) UPDATE_MANIFEST=true; shift ;;
    --fallback-github) FALLBACK_GITHUB=true; shift ;;
    --profile)
      ARTIFACT_PROFILE="${2:-}"
      shift 2
      ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \?//' | head -20
      exit 0
      ;;
    *) echo "未知参数: $1" >&2; exit 1 ;;
  esac
done

if [[ -n "$ONLY_VERSION" && -z "$ONLY_FRAMEWORK" ]]; then
  echo "使用 --version 时必须同时指定 --framework" >&2
  exit 1
fi

command -v mvn >/dev/null 2>&1 || { echo "需要 Maven (mvn)" >&2; exit 1; }

PY=python
command -v python3 >/dev/null 2>&1 && PY=python3
command -v "$PY" >/dev/null 2>&1 || { echo "需要 Python" >&2; exit 1; }

mkdir -p "$CACHE"

if [[ -n "$SCAN_POM" || ($UPDATE_MANIFEST && -z "$ONLY_VERSION") ]]; then
  ws="${SCAN_POM:-.}"
  echo ">>> 扫描 pom.xml: $(cd "$ws" 2>/dev/null && pwd || echo "$ws")"
  scan_args=(--workspace "$ws" --manifest "$MANIFEST")
  $UPDATE_MANIFEST && scan_args+=(--update-manifest)
  $FALLBACK_GITHUB && scan_args+=(--fallback-github)
  "$PY" "$ROOT/scripts/scan-pom-versions.py" "${scan_args[@]}"
  echo ""
fi

resolve_artifacts() {
  local fw="$1"
  "$PY" -c "
import json, sys
m=json.load(open('$MANIFEST', encoding='utf-8'))
cfg=m['frameworks'][sys.argv[1]]
profile=sys.argv[2]
arts=cfg.get('artifacts', [])
if profile and 'artifactsAlt' in cfg and profile in cfg['artifactsAlt']:
    arts=cfg['artifactsAlt'][profile]
print(','.join(arts))
" "$fw" "$ARTIFACT_PROFILE"
}

find_m2_jar() {
  local jar_name="$1"
  local candidates=(
    "$HOME/.m2/repository"
    "/c/Users/${USERNAME:-${USER}}/.m2/repository"
  )
  local base path
  for base in "${candidates[@]}"; do
    [[ -d "$base" ]] || continue
    path=$(find "$base" -name "$jar_name" 2>/dev/null | head -1)
    [[ -n "$path" && -f "$path" ]] && { echo "$path"; return 0; }
  done
  return 1
}

download_sources() {
  local group="$1" artifact="$2" version="$3" out_dir="$4"
  local jar_name="${artifact}-${version}-sources.jar"
  local jar_path="$CACHE/${group//./_}_${jar_name}"

  if [[ ! -f "$jar_path" ]]; then
    echo "  下载 sources: ${group}:${artifact}:${version}"
    if ! mvn -q org.apache.maven.plugins:maven-dependency-plugin:3.6.1:get \
      -Dartifact="${group}:${artifact}:${version}:jar:sources" \
      -Dtransitive=false; then
      echo "  警告: Maven 未找到 ${jar_name}，跳过" >&2
      return 1
    fi
    local m2_jar
    m2_jar=$(find_m2_jar "$jar_name") || {
      echo "  警告: 本地 .m2 中未找到 ${jar_name}" >&2
      return 1
    }
    cp "$m2_jar" "$jar_path"
  fi

  rm -rf "$out_dir/$artifact"
  mkdir -p "$out_dir/$artifact"
  unzip -qo "$jar_path" -d "$out_dir/$artifact"
  echo "  ✓ $artifact -> $out_dir/$artifact"
}

clone_eq_tests() {
  local version="$1" dest="$2"
  local repo="https://github.com/dromara/easy-query.git"

  rm -rf "$dest/git-sql-test"
  for tag in "v${version}" "${version}"; do
    if git ls-remote --tags "$repo" "refs/tags/${tag}" 2>/dev/null | grep -q .; then
      echo "  clone sql-test @ ${tag}"
      git clone --depth 1 --branch "$tag" --filter=blob:none --sparse "$repo" "$dest/git-sql-test"
      (cd "$dest/git-sql-test" && git sparse-checkout set sql-test)
      echo "  ✓ sql-test -> $dest/git-sql-test/sql-test"
      return 0
    fi
  done
  echo "  警告: easy-query ${version} 无匹配 git tag，跳过 sql-test" >&2
}

sync_one() {
  local fw="$1" ver="$2" group="$3"
  local artifacts
  artifacts=$(resolve_artifacts "$fw")
  echo ""
  echo "=== ${fw} @ ${ver} ==="
  local out_dir="$ROOT/vendor/${fw}/${ver}"
  mkdir -p "$out_dir"
  IFS=',' read -ra arts <<< "$artifacts"
  local art
  for art in "${arts[@]}"; do
    [[ -n "$art" ]] && download_sources "$group" "$art" "$ver" "$out_dir" || true
  done
  if $WITH_GIT_TESTS && [[ "$fw" == "easy-query" ]]; then
    clone_eq_tests "$ver" "$out_dir" || true
  fi
}

prune_old_versions() {
  local framework="$1"
  local base="$ROOT/vendor/$framework"
  [[ -d "$base" ]] || return 0

  mapfile -t kept < <("$PY" -c "
import json
m=json.load(open('$MANIFEST', encoding='utf-8'))
for v in m['frameworks']['$framework']['versions']:
    print(v)
")

  for dir in "$base"/*; do
    [[ -d "$dir" ]] || continue
    local ver keep=false k
    ver=$(basename "$dir")
    for k in "${kept[@]}"; do
      [[ "$ver" == "$k" ]] && keep=true
    done
    if [[ "$keep" == false ]]; then
      echo "  删除过期版本: $dir"
      rm -rf "$dir"
    fi
  done
}

echo ">>> 同步 vendor 源码"

if [[ -n "$ONLY_VERSION" ]]; then
  line=$("$PY" -c "
import json, sys
m=json.load(open('$MANIFEST', encoding='utf-8'))
fw, ver = sys.argv[1], sys.argv[2]
cfg=m['frameworks'][fw]
print(fw, ver, cfg['groupId'], sep='\t')
" "$ONLY_FRAMEWORK" "$ONLY_VERSION")
  IFS=$'\t' read -r fw ver group <<< "$line"
  sync_one "$fw" "$ver" "$group"
else
  while IFS=$'\t' read -r fw ver group; do
    [[ -z "$fw" ]] && continue
    if [[ -n "$ONLY_FRAMEWORK" && "$fw" != "$ONLY_FRAMEWORK" ]]; then
      continue
    fi
    sync_one "$fw" "$ver" "$group"
  done < <("$PY" -c "
import json
m=json.load(open('$MANIFEST', encoding='utf-8'))
for fw, cfg in m['frameworks'].items():
    for ver in cfg['versions']:
        print(fw, ver, cfg['groupId'], sep='\t')
")
fi

if ! $NO_PRUNE && [[ -z "$ONLY_VERSION" ]]; then
  while IFS= read -r fw; do
    [[ -z "$fw" ]] && continue
    if [[ -n "$ONLY_FRAMEWORK" && "$fw" != "$ONLY_FRAMEWORK" ]]; then
      continue
    fi
    echo ""
    echo "--- 清理 ${fw} 过期版本 ---"
    prune_old_versions "$fw"
  done < <("$PY" -c "
import json
m=json.load(open('$MANIFEST', encoding='utf-8'))
for fw in m['frameworks']:
    print(fw)
")
fi

echo ""
echo "完成。源码位于 vendor/<framework>/<version>/"
