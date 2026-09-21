# Skills

[English](README.en.md)

<p align="center">
  <img src="icon.png" width="192" alt="Skills 应用图标">
</p>

为 Vercel [`skills`](https://github.com/vercel-labs/skills) 命令提供原生 macOS 图形化工具，用于管理全局安装的 agent skills。所有行为都调用官方 skills CLI 来实现。

## 功能

- 浏览官方 skills.sh 目录，支持渐进加载和搜索。
- 将单个 skill 或 GitHub 仓库中明确勾选的多个 skills 安装到指定 agents。
- 支持符号链接和复制两种安装方式。
- 查看全局已安装 skills；更新和删除 skills，为已安装 skill 链接更多 agents。
- 选择兼容的 `bunx` 或 `npx` runtime，并选择要执行的 `skills` CLI 版本。
- 提供简体中文和英文界面。

## 环境要求

### 编译和运行应用

- macOS 26 或更高版本。
- Xcode 26 或更高版本，包含 macOS SDK。

### 在应用中管理 skills

- `PATH` 中存在兼容的 `bunx` 或 `npx` 启动器。
- 使用 `npx` 时需要 Node.js 22.20 或更高版本。
- 浏览和搜索需要访问 `skills.sh`。
- 私有 GitHub 源需要已有的 Git 凭据助手、SSH agent 或已认证的 `gh` 会话；应用不会收集凭据。

## 构建

```sh
make build
make run
```

构建产物位于 `.build/Build/Products/Debug/Skills.app`。

运行测试：

```sh
make test
```

## 安装 Release

Release 磁盘映像中的 `Skills.app` 使用 ad-hoc 签名，未经过公证。

1. 从 [Releases](../../releases) 下载并打开 `Skills-<version>-macos.dmg`。
2. 将 `Skills.app` 拖到 `/Applications`。
3. 在 Finder 中打开应用。若 macOS 阻止启动，请确认系统提示，或移除隔离属性：

   ```sh
   xattr -dr com.apple.quarantine /Applications/Skills.app
   ```

ad-hoc 签名可验证归档的代码结构，但不会向 Gatekeeper 标识已验证开发者。

## Release 自动化

推送名为 `v*` 的 tag 会触发 [`.github/workflows/release.yml`](.github/workflows/release.yml)。该工作流会运行测试，构建并保留 Xcode 生成的 ad-hoc 签名 universal Release（`arm64 + x86_64`），验证签名，制作 DMG，上传产物并创建 GitHub Release。

维护者也可手动运行工作流，并提供 release tag。

## 项目结构

- `skills/` — App 入口，以及按 `Core/`、`Models/`、`Services/`、`Views/`、`Resources/` 分类的应用源码和资源。
- `SkillsTests/` — Xcode 单元测试 target。
- `skills.xcodeproj/` — 管理应用和测试 target 的 Xcode 工程。

## 安全和范围

Skills 只管理全局 skills。已安装列表和所有变更均通过所选 `skills` CLI 处理，以保留 CLI 对 skill 来源、安装范围和 agent 关联关系的完整判断。安装目标必须显式选择，最后一次选择会保存在本机。

## 许可证

本项目采用 [MIT License](LICENSE)。
