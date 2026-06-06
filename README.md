# rustsilk-skill

面向 **Cursor / Codex / Claude Code Agent** 的 Java 领域 Skill 集合，帮助 AI 在编码场景中准确回答框架使用、配置与排错问题，减少 API 幻觉与空泛建议。

- 仓库内每个子目录为一个独立 Skill，命名前缀 **`rustsilk-skill-*`**
- 每个 Skill 含 **`SKILL.md`**（核心约束与回答流程）及可选 **`references/`**（按需展开的专题文档）
- 默认服务 **中文 Java 开发者**，**Spring Boot 优先**，编码示例优先于概念介绍

---

## Skill 列表

| Skill 名称 | 目录 | 适用框架 | 典型触发词 | 功能描述 |
|------------|------|----------|------------|----------|
| `rustsilk-easy-query` | [rustsilk-skill-easy-query](./rustsilk-skill-easy-query/) | [easy-query](https://github.com/dromara/easy-query) | `eq`、`easy-query`、`selectAutoInclude`、`include`、`toSQLResult` | easy-query ORM 专家：强类型 DSL、`EasyEntityQuery`、DTO/`selectAutoInclude`、多层级 `include`、SQL 预览与 `JdbcExecutorListener`、`asTreeCTE` 树查询、代理模式/`@EntityProxy`/`sql-processor`、Spring Boot 方言配置、Proxy 编译故障、IDEA 插件。 |
| `rustsilk-mybatis-plus` | [rustsilk-skill-mybatis-plus](./rustsilk-skill-mybatis-plus/) | [MyBatis-Plus](https://github.com/baomidou/mybatis-plus) + [MPJ](https://github.com/yulichang/mybatis-plus-join) | `MP`、`MPJ`、`baomidou`、`selectJoinList`、`MPJLambdaWrapper` | MyBatis-Plus 与 MyBatis-Plus-Join 专家：`BaseMapper`/`IService`、`LambdaQueryWrapper`/`Wrappers`、分页插件、`MPJBaseMapper`、`JoinWrappers`、连表 `selectJoinList`/`selectJoinPage`、`selectCollection`/`selectAssociation`、SQL 日志/`getSqlSegment`、starter 与 jsqlparser 依赖、连表 DTO 与报错排查。 |

> 新增 Skill 时：创建 `rustsilk-skill-<主题>/`，并在上表追加一行。

### 如何选择 Skill

| 你的问题涉及… | 应触发的 Skill |
|---------------|----------------|
| easy-query / eq / `EasyEntityQuery` / 代理 APT | `rustsilk-easy-query` |
| MyBatis-Plus / MPJ / `BaseMapper` / `MPJLambdaWrapper` | `rustsilk-mybatis-plus` |
| 「JPA 和 MyBatis 哪个好」等框架选型对比 | **均不触发**（Skill 不覆盖 ORM 对比） |

两个 Skill 可同时安装；Agent 会根据问题中的框架关键词自动选择。

---

## 目录结构

```
rustsilk-skill/
├── README.md
├── rustsilk-skill-easy-query/
│   ├── SKILL.md
│   └── references/
│       ├── core-api.md
│       ├── spring-boot-setup.md
│       ├── query-patterns.md
│       ├── dto-and-include.md
│       ├── sql-preview-and-testing.md
│       ├── cte-and-tree.md
│       ├── troubleshooting.md
│       └── plugin-and-apt.md
├── rustsilk-skill-mybatis-plus/
│   ├── SKILL.md
│   └── references/
│       ├── core-api.md
│       ├── spring-boot-setup.md
│       ├── query-patterns.md
│       ├── mpj-join.md
│       ├── dto-mapping.md
│       ├── sql-preview-and-testing.md
│       └── troubleshooting.md
└── rustsilk-skill-xxx/          # 后续 Skill（预留）
├── scripts/
│   ├── install.sh               # 一键安装（Bash）
│   └── install.ps1              # 一键安装（PowerShell）
```

---

## 安装

### 安装方式对比

| 方式 | 路径 | 适用场景 |
|------|------|----------|
| **用户级（默认）** | `~/.cursor/skills/` | 本机所有项目通用，个人开发推荐 |
| **项目级** | 本仓库 `.cursor/skills/` | 团队共享、随 git 克隆即用，需提交到版本库 |
| **Codex / Claude** | `~/.codex/skills/`、`~/.claude/skills/` | 对应 CLI / Claude Code 环境 |

**Cursor 项目级安装是支持的**：将 Skill 复制到仓库内 `.cursor/skills/<skill-name>/` 即可（与 Cursor 官方 [create-skill](https://cursor.com) 约定一致）。克隆本仓库后执行 `./scripts/install.sh --project` 即可写入项目级目录。

> 注意：项目级 Skill **不会**自动从用户级目录读取；二者择一或同时安装均可，重复安装同名 Skill 时以后写入的路径为准（视 Cursor 索引策略而定）。

### 一键安装（推荐）

在仓库根目录执行脚本，自动扫描并安装全部 `rustsilk-skill-*` 子目录：

```bash
# Bash — 用户级 Cursor（默认）
chmod +x scripts/install.sh
./scripts/install.sh

# 项目级（写入 .cursor/skills/，适合团队）
./scripts/install.sh --project

# Codex / Claude
./scripts/install.sh --codex
./scripts/install.sh --claude

# 一次装到 Cursor + Codex + Claude 用户目录
./scripts/install.sh --all
```

```powershell
# Windows PowerShell
.\scripts\install.ps1
.\scripts\install.ps1 -Target Project
.\scripts\install.ps1 -All
```

### 手动安装

```bash
# Linux / macOS / Git Bash — Cursor 用户级
mkdir -p ~/.cursor/skills
cp -r rustsilk-skill-easy-query ~/.cursor/skills/rustsilk-easy-query
cp -r rustsilk-skill-mybatis-plus ~/.cursor/skills/rustsilk-mybatis-plus

# 项目级
mkdir -p .cursor/skills
cp -r rustsilk-skill-easy-query .cursor/skills/rustsilk-easy-query
cp -r rustsilk-skill-mybatis-plus .cursor/skills/rustsilk-mybatis-plus
```

```powershell
# Windows PowerShell — Cursor 用户级
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.cursor\skills"
Copy-Item -Recurse rustsilk-skill-easy-query "$env:USERPROFILE\.cursor\skills\rustsilk-easy-query"
Copy-Item -Recurse rustsilk-skill-mybatis-plus "$env:USERPROFILE\.cursor\skills\rustsilk-mybatis-plus"
```

### 各平台路径

| 平台 | Skills 目录 | 说明 |
|------|-------------|------|
| Cursor 用户级 | `~/.cursor/skills/` | 全项目可用 |
| Cursor 项目级 | `<repo>/.cursor/skills/` | 随仓库分发，需 `git commit` |
| Codex CLI | `$CODEX_HOME/skills/`（默认 `~/.codex/skills/`） | 与 `SKILL.md` 中 `name` 字段对应 |
| Claude Code | `~/.claude/skills/` | 每 Skill 一个子目录 + `SKILL.md` |

### 前置要求

- Skill 目录内必须包含带 YAML frontmatter（`name`、`description`）的 **`SKILL.md`**
- 安装后建议 **重启 IDE 或重新加载窗口**，使 Agent 重新索引 Skill

### 只安装某一个 Skill

```bash
cp -r rustsilk-skill-easy-query ~/.cursor/skills/rustsilk-easy-query
# 或
cp -r rustsilk-skill-mybatis-plus ~/.cursor/skills/rustsilk-mybatis-plus
```

---

## 源码查证与版本说明

本仓库 **Skill 文本** 与 **框架上游源码** 是两层概念：

| 层级 | 是否自动跟踪 GitHub 最新 | 说明 |
|------|--------------------------|------|
| **rustsilk-skill 仓库** | 否 | Skill 内容随本仓库 git 更新；改 Skill 需 pull / 重新执行安装脚本 |
| **框架源码（回答依据）** | 可指向 GitHub 默认分支 | Skill 要求 Agent 优先查官方 GitHub / 文档，而非臆造 API |

各 Skill 的 **Source Priority** 已配置为 GitHub 仓库（例如 [dromara/easy-query](https://github.com/dromara/easy-query) 的 `main` 分支、`sql-test/` 模块）。Agent 在具备网络或已 clone 源码到工作区时，应以 **GitHub 上对应分支的最新代码与测试** 为准核对 API。

**实践建议：**

1. **一般使用** — 安装 Skill 即可；提问时附上 `pom.xml` 中的框架版本，Agent 结合官方文档回答。
2. **需要对齐最新未发布 API** — 将框架仓库 clone 到本地并放入 Cursor 工作区，或让 Agent 通过 GitHub 查阅 `main` 分支；提问中说明「请以 GitHub main 为准」。
3. **版本敏感** — 务必提供 easy-query / MP / MPJ 的版本号；Skill 不会替用户锁定「永远等于 Maven Central 最新版」。

**说明：** Skill 本身不包含框架源码，也**不会**自动 `git pull` 上游仓库；若团队需要固定某一 tag 的源码对照，请在业务项目中 submodule 或 clone 指定 tag，并在对话中声明版本。

---

## 使用方式

Skill 由 Agent **自动触发**，一般无需手动 `@` 引用。

1. **直接提问** — 带上框架名与具体场景（配置、写法、报错栈）
2. **Agent 读 SKILL.md** — 按回答流程、source priority 与语义约束作答
3. **复杂专题** — Agent 按需加载 `references/` 下的文档，避免一次输出过长教程

### 提问示例

**easy-query**

- Spring Boot 里 `easy-query.database` 怎么配？启动报方言未选择。
- `selectAutoInclude` 和 `include` 有什么区别？为什么 `toSQLResult` 看不到 include 的 SQL？
- `@EntityProxy` 编译后 proxy 包不存在怎么排查？

**MyBatis-Plus / MPJ**

- Mapper 要继承 `MPJBaseMapper` 吗？`selectJoinList` 怎么用？
- 一对多连表返回嵌套 List，用 `selectCollection` 怎么写？
- `getSqlSegment()` 为什么不是完整 SQL？开发环境怎么打印 SQL？

### 触发建议

版本敏感问题请补充：

- **框架版本**（如 easy-query 3.2.x、MP 3.5.16、MPJ 1.5.7）
- **Spring Boot 版本**（2 / 3 / 4）
- **数据库类型**（MySQL、PostgreSQL 等）
- **easy-query 专属**：是否代理模式、是否 IDEA 插件

### 验证 Skill 是否生效

| Skill | 合格回答应… |
|-------|-------------|
| `rustsilk-easy-query` | 优先 `EasyEntityQuery`；区分 `include` / `selectAutoInclude` / `toSQLResult`；不编造 eq API |
| `rustsilk-mybatis-plus` | 单表用 `LambdaQueryWrapper`，连表用 `MPJLambdaWrapper` + `selectJoinList`；说明 `getSqlSegment` 仅为片段 |

---

## 开发与贡献

### 新增 Skill 步骤

1. 创建 `rustsilk-skill-<主题>/`
2. 编写 `SKILL.md`（frontmatter 含 `name`、`description`；description 写清触发场景）
3. 专题示例、排查清单放入 `references/`，主文件保持精简（progressive disclosure）
4. 更新本 README **Skill 列表** 与 **目录结构**

### 设计原则

| 原则 | 说明 |
|------|------|
| 编码优先 | 可运行的 Spring Boot 示例，避免伪代码与宣传文案 |
| 不硬编 API | 不确定时明确说明，并让用户补充版本与环境 |
| 边界清晰 | 不扩展无关 ORM 对比、不写框架选型软文 |
| 语义准确 | 如 eq 的 `distinct` vs 主键去重、MP 的 `getSqlSegment` vs 完整 SQL |

---

## 官方文档与源码

### easy-query

- [官方文档](https://www.easy-query.com/easy-query-doc/)
- [GitHub — dromara/easy-query](https://github.com/dromara/easy-query)

### MyBatis-Plus

- [快速开始](https://baomidou.com/getting-started/)
- [GitHub — baomidou/mybatis-plus](https://github.com/baomidou/mybatis-plus)

### MyBatis-Plus-Join

- [介绍与快速开始](https://mybatis-plus-join.github.io/pages/quickstart/introduce.html)
- [GitHub — yulichang/mybatis-plus-join](https://github.com/yulichang/mybatis-plus-join)

---

## 许可证

本仓库 Skill 内容仅供学习与团队内部 Agent 增强使用。  
easy-query、MyBatis-Plus、MyBatis-Plus-Join 等框架遵循各自官方仓库许可证（Apache-2.0）。
