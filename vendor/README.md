# vendor 源码缓存

## artifacts 是什么？

Maven **`<artifactId>`**，与 `groupId` + `version` 一起定位 `*-sources.jar`。

### easy-query（Spring Boot 日常）

| artifactId | 说明 |
|------------|------|
| `sql-springboot4-starter` | Boot 4 主依赖（默认 artifacts） |
| `sql-springboot-starter` | Boot 2/3（`--profile springBoot3`） |
| `sql-processor` | APT，`provided` |
| `sql-api-proxy` | 代理 API（starter 传递，单独拉 sources 便于 Agent 查阅） |
| `sql-core` | 核心实现（**含在 starter 中**；`artifactsAlt.deepCore` 可选） |

### MyBatis-Plus / MPJ

见 [versions.json](./versions.json) 中 `artifacts` 与 `artifactsAlt`。

---

## 版本不在 versions.json？

json 只是**预缓存**，不是白名单。Agent 仍用 `.m2` / GitHub tag。

人工补缓存：

```bash
./scripts/sync-vendor-sources.sh --framework easy-query --version 3.2.7 --no-prune
```

---

## 维护命令

```bash
# 扫业务项目 pom，更新 json 并 sync
./scripts/sync-vendor-sources.sh --scan-pom /path/to/project --update-manifest

# 无 pom：GitHub 最新 Release 写入 json
./scripts/sync-vendor-sources.sh --scan-pom . --update-manifest --fallback-github
```

详见根目录 [README.md](../README.md#sync-vendor-sourcessh-使用说明)。
