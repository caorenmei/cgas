---
name: git-worktree-manager
description: |
  当用户有以下需求时调用此 skill：
  - 创建分支（新建 feature/功能分支）
  - 删除分支
  - 创建 worktree（"worktree add"、"新建 worktree"、"添加 worktree"）
  - 删除 worktree（"worktree remove"、"清理 worktree"、"移除 worktree"）

  **不触发的情况**：
  - 只读 git 操作（status、log、diff、branch --list 等）
  - 用户已在 worktree 目录内询问开发问题
---

# Git Worktree Manager

封装项目中 Git Worktree 的创建、命名、环境文件拷贝和清理等完整流程。

## 目录路径规范

- Worktree 必须创建在项目根目录下的 `.worktrees/` 子目录中。
- **禁止**将 worktree 放在 `.claude/worktrees/` 等其他位置。

## 命名规范

- `<feature>` 目录名与分支名对应。
- 分支名中的 `/` 替换为 `-` 作为目录名。
- 例如：分支 `futures/pvp` 对应目录 `.worktrees/futures-pvp`。

## 创建 Worktree 的完整流程

### 1. 前置检查

- 检查目标目录 `.worktrees/<feature>` 是否已存在：
  - 若已存在：询问用户是否覆盖（需先删除再重建），或改用其他目录名。
  - 若不存在：继续下一步。
- 检查分支是否存在：
  - `git branch --list <branch>` 或 `git show-ref --verify --quiet refs/heads/<branch>`
  - 若返回结果非空 → 分支已存在
  - 若返回结果为空 → 分支不存在，创建时需加 `-b`

### 2. 创建 Worktree

- 分支**已存在**：`git worktree add .worktrees/<feature> <branch>`
- 分支**需新建**：`git worktree add .worktrees/<feature> -b <branch>`

### 3. 环境文件拷贝

创建 worktree 后，必须将 `.worktreeinclude` 中列出的文件/目录拷贝到新 worktree 根目录下，以便各 worktree 拥有独立的构建环境、工具脚本和本地配置。

**拷贝规则**：
- 逐行读取 `.worktreeinclude` 中的条目
- 对每个条目，先检查源路径是否存在（`-e` / `Test-Path`）
- 若存在则拷贝；若不存在则跳过并记录警告，不中断流程
- 目录和文件都需要支持（`cp -r` / `Copy-Item -Recurse` 对两者都有效）

#### Windows (PowerShell)

```powershell
$feature = "<feature>"
$items = Get-Content .worktreeinclude
foreach ($item in $items) {
    $item = $item.Trim()
    if ([string]::IsNullOrWhiteSpace($item)) { continue }
    if (Test-Path $item) {
        Copy-Item -Recurse -Force $item ".worktrees/$feature/"
        Write-Host "Copied: $item"
    } else {
        Write-Warning "Skipped (not found): $item"
    }
}
```

#### Bash / Unix-like

```bash
feature="<feature>"
while IFS= read -r item; do
    item="$(echo "$item" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [ -z "$item" ] && continue
    if [ -e "$item" ]; then
        cp -r "$item" ".worktrees/$feature/"
        echo "Copied: $item"
    else
        echo "Warning: skipped (not found): $item" >&2
    fi
done < .worktreeinclude
```

### 4. 验证

- 检查 `.worktrees/<feature>/` 目录存在且包含预期的文件/目录
- 检查 `.worktrees/<feature>/.git` 文件存在（worktree 的 git 链接文件）

## 删除/清理 Worktree 的流程

### 1. 前置确认

- 列出当前所有 worktree：`git worktree list`
- 确认用户要删除的目标 worktree 路径和分支名
- **警告**：删除前确认该 worktree 内没有未提交的修改或未推送的提交

### 2. 删除步骤

```bash
# 1. 移除 worktree 注册（不会删除目录）
git worktree remove .worktrees/<feature>

# 若目录仍残留（如包含未跟踪文件导致 remove 失败），强制删除：
git worktree remove --force .worktrees/<feature>

# 2. 清理已删除 worktree 的注册信息（可选但推荐）
git worktree prune

# 3. 若分支不再需要，可一并删除
git branch -d <branch>    # 已合并的分支
git branch -D <branch>    # 强制删除（无论是否合并）
```

### 3. 删除后验证

- `git worktree list` 确认目标 worktree 已不在列表中
- 确认 `.worktrees/<feature>/` 目录已被删除（或手动删除残留）

## 完整流程示例

### 示例 1：已有分支

```bash
# 1. 检查分支是否存在
git branch --list futures/pvp
# 输出: * main
#        futures/pvp   <-- 分支已存在

# 2. 检查目标目录是否已存在
# 若 .worktrees/futures-pvp 已存在 → 询问用户是否覆盖
# 若不存在 → 继续

# 3. 创建 worktree
git worktree add .worktrees/futures-pvp futures/pvp

# 4. 拷贝环境文件（PowerShell）
$feature = "futures-pvp"
$items = Get-Content .worktreeinclude
foreach ($item in $items) {
    $item = $item.Trim()
    if ([string]::IsNullOrWhiteSpace($item)) { continue }
    if (Test-Path $item) {
        Copy-Item -Recurse -Force $item ".worktrees/$feature/"
    } else {
        Write-Warning "Skipped (not found): $item"
    }
}

# 5. 验证
git worktree list
ls .worktrees/futures-pvp/
```

### 示例 2：新建分支

```bash
# 1. 检查分支是否存在
git branch --list futures/pvp
# 输出: * main
#        （无 futures/pvp） <-- 分支不存在

# 2. 检查目标目录是否已存在
# 若 .worktrees/futures-pvp 已存在 → 询问用户是否覆盖
# 若不存在 → 继续

# 3. 创建 worktree（带 -b 新建分支）
git worktree add .worktrees/futures-pvp -b futures/pvp

# 4. 拷贝环境文件（Bash）
feature="futures-pvp"
while IFS= read -r item; do
    item="$(echo "$item" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [ -z "$item" ] && continue
    if [ -e "$item" ]; then
        cp -r "$item" ".worktrees/$feature/"
    else
        echo "Warning: skipped (not found): $item" >&2
    fi
done < .worktreeinclude

# 5. 验证
git worktree list
ls .worktrees/futures-pvp/
```

### 示例 3：删除 Worktree

```bash
# 1. 列出所有 worktree
git worktree list

# 2. 删除指定 worktree
git worktree remove .worktrees/futures-pvp

# 3. 清理注册信息
git worktree prune

# 4. 验证
git worktree list
```

## 注意事项

- 主工作区应保持 `main` 分支。
- 各 worktree 独立构建，互不干扰。
- `.worktreeinclude` 中不存在的条目会被跳过并记录警告，不会中断整个拷贝流程。
- 删除 worktree 前务必确认没有未提交的修改，避免数据丢失。
