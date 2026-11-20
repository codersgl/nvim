# VSCode + VSCodeVim → 对齐本机 LazyVim

把 VSCode 的按键改造成尽量贴合 `~/.config/nvim`（LazyVim，`lazyvim.json` version 8）的手感。

```
vscode/
├── keybindings.json   ← 全文替换 C:\Users\石国亮\AppData\Roaming\Code\User\keybindings.json
├── settings.json      ← 合并版（你的原 settings.json，只替换了 vim.* 那一段）
└── README.md          ← 本文件
```

---

## 一、为什么要分成两个文件（先看这个，不然会觉得 keybindings.json 太短）

VSCode 解析按键的优先级是：

```
keybindings.json  >  扩展贡献的键位（含 VSCodeVim 自己的）  >  VSCodeVim 内部映射
```

由此决定了两边各放什么：

| 放哪 | 放什么 | 原因 |
| --- | --- | --- |
| **settings.json**<br>`vim.*ModeKeyBindingsNonRecursive` | 所有 vim 模式下的键：`<leader>ff`、`<leader>ca`、`gd`、`[d`、`<A-j>`、`<leader>\|` | 那里用的是**真正的 vim 记法**。`<leader>\|`、`<C-/>`、`<A-j>`、`[b` 都能原样写。keybindings.json 的 `key` 字段是「VSCode 按键名」，`<leader>\|` 得写成 `"space shift+\\"`，别扭且依赖键盘布局 |
| **keybindings.json** | ① VSCode 自己已占用、VSCodeVim 抢不过的键（`ctrl+j`、`ctrl+k`）<br>② 要在编辑器**之外**也生效的键（`ctrl+/` 切终端） | 这两类写在 settings.json 里会被 VSCode 默认键位吃掉，或根本不在编辑器里生效 |

VSCodeVim 的 `before` 里可以直接写 VSCode 命令 ID（`"commands": ["workbench.action.quickOpen"]`），
所以两边能力等价，只是记法精确度不同。

---

## 二、概念对应（后面所有映射都基于这个）

| nvim | VSCode | 说明 |
| --- | --- | --- |
| buffer | 打开的文件 / 编辑器 tab | `<S-h>` `<S-l>` `<leader>bd` 等 |
| window | editor group（分屏） | `<C-h/j/k/l>` `<leader>-` `<leader>\|` `<leader>wd` |
| tabpage | **没有对应物** | 下面用 group 内的编辑器近似 `<leader><tab>...` |

---

## 三、键位表

### 跨区域方向移动：编辑区 ↔ 文件树 ↔ 终端（在 keybindings.json）★

用的命令是 VSCode 自带的 `workbench.action.navigateLeft / Right / Up / Down`
（菜单名 `View: Navigate to the View on the Left / Right / Above / Below`），
语义就是 nvim 的 `<C-h/j/k/l>`：**先在同一方向的 editor group 之间跳，该方向
没有分屏时回落到相邻区域**（左 = 文件树，下 = 面板/终端，右 = 右侧栏）。

| 焦点在哪 | `<C-h>` | `<C-j>` | `<C-k>` | `<C-l>` |
| --- | --- | --- | --- | --- |
| 编辑器（Normal 模式） | 左侧分屏，否则**文件树** | 下方分屏，否则**面板/终端** | 上侧分屏 | 右侧分屏，否则右侧栏 |
| 文件树 | 左侧相邻区域 | **面板/终端** | 上方相邻区域 | **编辑区** |
| 面板（问题/输出/调试控制台） | **文件树** | — | **编辑区** | 右侧栏 |
| 终端 | *(留给 shell 的退格)* | 开关面板（VSCode 默认） | **跳回编辑区** | *(留给 shell 的清屏)* |

`<C-/>` = 终端开关（编辑器内非 insert 模式 + 编辑器外都可）。

**为什么换掉了原来的 `focusLeftGroup` 那一套**：只有一个编辑组时
`focusLeftGroup` 什么都不做，所以以前从编辑区**永远跳不到文件树** ——
这就是「不一致」的根源。`navigate*` 在没有相邻分屏时会回落到相邻区域，
四个方向才对称。这四个命令 VSCode 默认没绑任何键，而且都在终端的
`commandsToSkipShell` 内置列表里，所以终端里也能生效。

⚠️ 两个刻意的取舍：

1. **区域不可见时不会顺手打开它**（和 vim 里该方向没有窗口就什么都不做一致）：
   文件树用 `<leader>e` 开，终端用 `<C-/>` 或 `<leader>t` 开。
2. **终端里只接管了 `<C-k>`**。终端里一旦绑定某组合键，shell 就收不到了：
   `Ctrl+H` 是退格、`Ctrl+L` 是清屏，抢了会很难受（你 nvim 配置里那段
   「不能抢 Esc」的注释就是这个取舍）；而 `Ctrl+J` 已被 VSCode 默认占为
   开关面板、`Ctrl+K` 已被 chord 机制吞掉，所以只拿 `Ctrl+K` 跳回编辑区，白赚。
   想让四个方向在终端里也完全对称，见第七节。

### 文件树单键：对齐 snacks explorer（在 keybindings.json）

你 nvim 里的 explorer 是 snacks 的，它是个**模态** picker，所以能用单键做文件操作。
VSCode 的文件树默认**没有**这些键（我解码了 explorer 那段键位注册簇：默认只有
`F2` / `Delete` / `Shift+Delete` / `Ctrl+C·X·V` / `Esc` / `Space`；`explorer.newFile`
只注册了命令 + 右键菜单 + 命令面板，**一条键位都没有**）。下面是按 snacks 补的：

| 键 | snacks | VSCode 命令 | 说明 |
| --- | --- | --- | --- |
| `a` | `a` 新建 | `explorer.newFile` | 新建文件 |
| `A` | *(snacks 用 `a` + 结尾 `/`)* | `explorer.newFolder` | 新建文件夹（VSCode 分不了后缀写法，所以拆成两个键） |
| `r` | `r` 重命名 | `renameFile` | 同原生 `F2` |
| `d` | `d` 删除 | `moveFileToTrash` / `deleteFile` | 两段式，和原生 `Delete` 一致：能进回收站就进（可恢复），否则永久删除 |
| `c` | `c` 复制 | `filesExplorer.copy` | 同原生 `Ctrl+C` |
| `m` | `m` 移动 | `filesExplorer.cut` | 同原生 `Ctrl+X` |
| `y` | `y` yank | `filesExplorer.copy` | VSCode 的 copy 同时把**路径文本写进系统剪贴板**并让 `p` 能粘贴文件 —— 正好等价于 snacks 的 y |
| `Y` | *(无)* | `copyRelativeFilePath` | 只要路径文本、不要文件剪贴板时用 |
| `p` | `p` 粘贴 | `filesExplorer.paste` | 同原生 `Ctrl+V` |
| `u` | `u` 刷新 | `workbench.files.action.refreshFilesExplorer` | |
| `.` | `.` 定位当前文件 | `workbench.files.action.showActiveFileInExplorer` | |
| `o` | `o` 系统程序打开 | `revealFileInOS` | |
| `h` | `h` 折叠 / `<BS>` 上级 | `list.collapse` | VSCode 的语义是「展开着就折叠，已折叠就跳父项」，一个键覆盖 snacks 的 h 和 `<BS>` |
| `l` | `l` 打开 | `list.select` | 原生 `Enter` 触发的就是它；万一没反应就用 `Enter` |

**守卫条件不是我猜的**：Workbench 源码里 explorer 自己的键位注册写成
`r_ = T.and(AX, q3i, T.not(Bh))`，其中 `AX = foldersViewVisible`、
`q3i = filesExplorerFocus`（由树自己的 scoped contextKeyService 绑定）、
`Bh = "inputFocus"`。所以这里逐字照抄成
`foldersViewVisible && filesExplorerFocus && !inputFocus`，
保证只在文件树真正有焦点时生效 —— **在编辑器里按 `a` 仍然是插入字符**。

⚠️ **刻意接受的代价**：VSCode 的树没有模态概念，绑定单键会占掉这些字母的
**打字跳转**（`workbench.list.typeNavigationMode` 默认 `"automatic"`：在树里直接打
字母可以跳到同名文件）。snacks 是模态 buffer，所以那边单键没有这个代价。
另外 VSCode 原生键**一条都没删**：`F2` / `Delete` / `Shift+Delete` /
`Ctrl+C·X·V` / `Enter` / `Space` 仍然全部可用。

### 通用

| 键 | 动作 |
| --- | --- |
| `<leader>ur` | 清除搜索高亮 |
| `<leader>qq` | 退出全部 |
| `<leader>l` | 扩展面板（≈ Lazy） |
| `<leader>e` | **文件树开 / 关**（`toggleSidebarVisibility`） |
| `<leader>E` | 强制切到文件树（侧边栏正显示 SCM/扩展时换回来） |
| `<leader>t` `<leader>ft` `<leader>fT` `<C-/>` | 终端 |
| `<A-j>` `<A-k>` | 上/下移动行 |
| `<C-o>` `<C-i>` | **跳转历史 后退 / 前进**（`workbench.action.navigateBack` / `navigateForward`）—— 见下方说明 |

> **`<C-o>` / `<C-i>` 为什么用 VSCode 的导航历史，而不是 VSCodeVim 的 jumplist**
>
> VSCodeVim 的 `<C-o>` 走 `jumpTracker.jumpBack`，而它只在「命令带 `isJump`」时才
> `recordJump`（原生 `gd` 是 `this.isJump = !0`）。但本配置里 `gd` / `gr` / `gy` / `gI`
> 都是 `commands` 形式的 remap —— VSCodeVim 执行这类 remap 时是**裸调用**
> `vscode.commands.executeCommand(...)`，**不带 isJump、不记录**。于是这些跳转全都
> 不进 jumplist，`<C-o>` 就没有「上一个位置」可回。
>
> 改用 VSCode 的导航历史（`navigateBack` / `navigateForward`）后，跳转由编辑器服务
> 记录，**不管是谁触发的**都算：`gd`、`<leader>gr` 的引用跳转、`<leader>ff` / `Ctrl+P`
> 换文件、鼠标点击。代价是它**不记录文件内的小跳**（`/` 搜索、mark）—— VSCodeVim 的
> jumplist 记这些却不记上面那些。两者互有取舍，这里选了更常用的那侧。

### buffer（`<leader>b`）

| 键 | 动作 |
| --- | --- |
| `<S-h>` `<S-l>` / `[b` `]b` | 上一个 / 下一个 buffer |
| `[B` `]B` | 左右移动 buffer |
| `<leader>bb` `` <leader>` `` | 切到另一个 buffer |
| `<leader>bd` | 关闭当前 buffer |
| `<leader>bo` | 关闭其它 buffer |
| `<leader>bj` | 选择 buffer |
| `<leader>bl` `<leader>br` | 关闭左 / 右侧 buffer |
| `<leader>bp` `<leader>bP` | pin / unpin（VSCode 无「固定 buffer」，用 pin 近似） |

### 查找（`<leader>f`）

| 键 | 动作 |
| --- | --- |
| `<leader><space>` `<leader>ff` `<leader>fF` `<leader>fg` | 找文件 |
| `<leader>fb` `<leader>fB` `<leader>,` | buffer 列表 |
| `<leader>fc` | 打开 settings.json |
| `<leader>fr` `<leader>fR` | 最近文件 → **`quickOpen`**。VSCode 的 `openRecent` 是「最近*工作区*」选择器，不是最近文件；最近文件在 VSCode 里就是 `Ctrl+P` 的默认排序（空查询按最近使用排），所以 `fr` 和 `ff` 落到同一个命令上 —— 这是 VSCode 的设计，不是漏配 |
| `<leader>fp` | Projects → **`openRecent`**（最近工作区，正好等价于 LazyVim 的 projects 列表）。原来误写成 `workbench.action.openFolder`，那个 ID 在 VSCode 1.139 里**不存在**，属于静默失效；「打开文件夹」的正确 ID 是 `workbench.action.files.openFolder` |
| `<leader>fe` | 文件树开 / 关（同 `<leader>e`） |
| `<leader>fE` | 强制切到文件树 |
| `<leader>fn` | 新建文件 |

### 搜索（`<leader>s`）

| 键 | 动作 |
| --- | --- |
| `<leader>/` `<leader>sg` `<leader>sG` | 全局搜索 |
| `<leader>sw` `<leader>sW` | 搜索光标下词 / 选区（见第五节） |
| `<leader>sd` | 问题列表 |
| `<leader>ss` | 文档符号 |
| `<leader>sS` | 工作区符号 |
| `<leader>sk` | 快捷键列表 |
| `<leader>sc` `<leader>:` | 命令面板 |
| `<leader>sr` | 全局替换 |
| `<leader>sh` | 帮助文档 |
| `<leader>sn` | 通知中心 |

### 代码 / LSP（`<leader>c`）

| 键 | 动作 | 备注 |
| --- | --- | --- |
| `<leader>ca` | Code Action | |
| `<leader>cr` | 重命名 | |
| `<leader>cf` | 格式化 | visual 模式下是格式化选区 |
| `<leader>co` | 整理 import | |
| `<leader>cs` | 文档符号 | |
| `gd` | 跳转**定义**（`revealDefinition`） | VSCodeVim 原生 `gd` 走的其实是 `goToDeclaration`（跳声明，C/C++ 下会跳到头文件），已按 LazyVim 补正 |
| `gD` | 跳转**声明** | VSCodeVim 原生行为已正确，未重定义 |
| `K` | hover 悬浮信息 | **VSCodeVim 1.32.4 里没有 `K` 的绑定**（343 条键位查过，hover 绑在 `gh` 上），已显式补上；不补的话 `K` 是空键 |
| `gK` | 签名帮助 | VSCodeVim 无此键，已补（插入模式的 `<C-k>` 同样可用） |
| `gr` `gy` `gI` | 引用 / 类型定义 / 实现 | VSCodeVim 无这三个，已补 |
| `<C-k>`（insert） | 签名帮助 | |

### Git（`<leader>g`）

| 键 | 动作 |
| --- | --- |
| `<leader>gg` `<leader>gs` | 源代码管理面板 |
| `<leader>gd` `<leader>gD` | 当前改动 / 全部改动 diff |
| `<leader>gb` | 行 blame（编辑器装饰） |
| `<leader>gS` | stash |

### 调试（`<leader>d`，对应你装的 `dap.core` extra）

| 键 | 动作 | 键 | 动作 |
| --- | --- | --- | --- |
| `<leader>da` | 启动 | `<leader>di` | Step Into |
| `<leader>dc` | 继续 | `<leader>do` | Step Out |
| `<leader>dl` | 运行上次配置 | `<leader>dO` | Step Over |
| `<leader>db` | 断点开关 | `<leader>dP` | 暂停 |
| `<leader>dB` | 条件断点 | `<leader>dt` | 终止 |
| `<leader>dC` | 运行到光标 | `<leader>dr` | 切换 REPL |
| `<leader>du` | 调试面板 | | |

### 界面（`<leader>u`）与窗口

| 键 | 动作 |
| --- | --- |
| `<leader>uw` | 切换自动折行 |
| `<leader>ub` | 切换亮/暗主题 |
| `<leader>uC` | 选择配色 |
| `<leader>uz` | Zen 模式 |
| `<leader>uZ` `<leader>wm` | 最大化当前 group（≈ Zoom） |
| `<leader>un` | 清空通知 |
| `<leader>-` `<leader>\|` | 向下 / 向右分屏 |
| `<leader>wd` | 关闭当前 group |
| `<leader><tab><tab>` `<leader><tab>d` | 新建 / 关闭编辑器 |
| `<leader><tab>o` | 关闭其它编辑器 |
| `<leader><tab>]` `<leader><tab>[` | 下一个 / 上一个编辑器 |
| `<leader><tab>f` `<leader><tab>l` | 第一个 / 最后一个 |

### 诊断

| 键 | 动作 |
| --- | --- |
| `<leader>xx` | 问题列表 |
| `]d` `[d` | 文件内下一个 / 上一个问题 |
| `]e` `[e` | 跨文件下一个 / 上一个问题 |
| `]q` `[q` | 同上（VSCode 无法区分 quickfix/loclist，用同一命令近似） |

### Visual 模式

| 键 | 动作 |
| --- | --- |
| `<leader>cf` | 格式化选区 |
| `<leader>ca` | Code Action |
| `<leader>sw` `<leader>sW` | 搜索选区 |
| `<A-j>` `<A-k>` | 移动选中行 |

---

## 四、相对你原来的配置，改了什么（★ 重点看）

原来的 `vim.normalModeKeyBindingsNonRecursive` 里有 7 处和本机 LazyVim **冲突**，
按「尽量贴合 nvim」的目标做了如下调整：

| 原来的键 | 原来是 | 问题 | 现在 |
| --- | --- | --- | --- |
| `<leader>d` | `dd` | LazyVim 里 `<leader>d` 是 **debug 组**，而你装了 `dap.core` | 删除；删行直接用 `dd`；`<leader>d*` 改为调试键 |
| `<leader>w` | `:w` 保存 | LazyVim 里 `<leader>w` 是 **windows 组**（有 `wd`/`wm`） | 删除；保存用 `:w` 或 `Ctrl+S`；`<leader>wd`/`wm` 归位 |
| `<leader>h` `<leader>l` | 上一个/下一个 tab | LazyVim 的 tab 键是 `<leader><tab>[` / `]`；且 `<leader>l` 已被 Lazy 占用 | 删除；改用 `<leader><tab>[...]`（`<leader>l` 现为扩展面板） |
| `<leader>v` `<leader>s` | `:vsplit` / `:split` | `<leader>s` 是 LazyVim 的 **search 组**；分屏键是 `<leader>-` / `<leader>\|` | 删除；改用 `<leader>-` / `<leader>\|` |
| `<leader>/` | 注释当前行 | LazyVim 里 `<leader>/` 是 **全局搜索** | 改为全局搜索；注释用 `gcc`（VSCodeVim 原生支持） |
| `<leader>f` | `quickOpen` | 会立刻触发，导致 `<leader>ff`/`fb`/`fr` 等全部无法使用 | 删除；改用 `<leader><space>` 和 `<leader>ff` |
| `K` | `lineBreakInsert` | LazyVim 里 `K` 是 **hover**（VSCodeVim 原生支持） | 删除；换行用 `o` / `O` |
| `>` `<`（Normal 模式） | 变成 `>>` / `<<` | 会让 `>` `<` **无法当操作符用**（`>ap`、`>j`、`>i{` 全失效） | 删除；`>>` `<<` 照旧，`<leader>>`/`<leader><` 保留 |

**同时保留了你原来这些不冲突的习惯**：
`jk` 退出插入、`<leader>r` 用系统剪贴板替换词、`<C-n>` 清高亮、
`<leader>>`/`<leader><` 快速缩进、`<leader>t` 开终端。

**新增的对齐项**：`<leader>xo` → 用 Windows 默认程序打开当前文件（对齐你 nvim 里的 `<leader>xo`）。

---

## 五、无法对齐的部分（不是漏了）

| LazyVim | 为什么做不到 |
| --- | --- |
| `<leader>gl` `<leader>gL` `<leader>gf`（git log / 文件历史） | VSCode **内置 git 扩展根本没有** log / file-history 命令（只有 Timeline）。装了 GitLens 才能补 |
| `<leader>ul` `<leader>uL` `<leader>ud` `<leader>uT` `<leader>ug` `<leader>uh` `<leader>ua` | 行号/诊断/树解析/缩进线/inlay hints 在 VSCode 里是**设置项，没有开关命令**（主题、折行、Zen、最小地图这几个才有命令，已映射） |
| `<leader>ss` 的「调用关系」`gai`/`gao`、`]]`/`[[` 引用跳转 | VSCode 无对应命令 |
| `<leader>st` `<leader>sT` `<leader>xt`（todo 注释） | 需要 Todo Tree 之类的扩展 |
| `<leader>qs` `<leader>ql`（session 恢复） | VSCode 没有 nvim 式 session；可用「最近打开」近似 |
| snacks explorer 的 `H` 切换隐藏文件、`I` 切换 ignored | VSCode **没有这类开关命令**（整个 bundle 搜过，`workbench.action.toggleHiddenFiles` 之类都不存在）；隐藏文件只能改 `files.exclude` 设置 |
| snacks explorer 的 `Z`（全部折叠/关闭）、`<BS>`（跳上级） | 没有独立命令；`h`（`list.collapse`）已覆盖「折叠 / 回父项」 |
| `<leader>yi`（复制图片到剪贴板）、`<leader>uo`（图片内联渲染） | 这是你 nvim 里的 Lua 自定义，VSCode 侧无等价能力 |
| which-key 提示浮窗 | VSCode 无内置；可装 `VSpaceCode.whichkey`，但它有自己的 `whichkey.bindings` 配置源，会和本方案重复，装之前先想清楚 |

---

## 六、安装步骤

设 `USER = C:\Users\石国亮`。

1. **先备份**
   ```powershell
   copy "%APPDATA%\Code\User\settings.json"    "%APPDATA%\Code\User\settings.json.bak"
   copy "%APPDATA%\Code\User\keybindings.json" "%APPDATA%\Code\User\keybindings.json.bak"
   ```
2. 把 `vscode/keybindings.json` 复制成 `%APPDATA%\Code\User\keybindings.json`（全文替换，原文件是空的）。
3. 把 `vscode/settings.json` 复制成 `%APPDATA%\Code\User\settings.json`。
   - 这是**你的原文件**，只替换了 `vim.*` 那一段（第 188–300 行），其余 142 项设置和注释一字未动。
   - 如果你已经自己改过 settings.json，请改为手动替换那一段，别直接覆盖。
4. `Ctrl+Shift+P` → **Developer: Reload Window**。
5. 验证：`Ctrl+Shift+P` → **Preferences: Open Keyboard Shortcuts**，搜索 `focusLeftGroup`，
   能看到 4 条带 `vim.mode == 'Normal'` 条件的 `Ctrl+H/J/K/L` 就说明 keybindings.json 生效了。

> 你机器上还有 **Cursor**（`%APPDATA%\Cursor`）。它的快捷键是独立的一份，需要的话把
> `keybindings.json` 同样复制到 `%APPDATA%\Cursor\User\`，`vim.*` 那段也一并合过去。

---

## 七、可选的进一步调整

- **让终端里的四方向移动完全对称**：默认在终端里只接管了 `<C-k>`（跳回编辑区），
  因为 `Ctrl+H`（退格）、`Ctrl+L`（清屏）一旦绑定，shell 就收不到了。想对称，在
  settings.json 加
  `"terminal.integrated.commandsToSkipShell": ["workbench.action.navigateLeft", "workbench.action.navigateRight"]`，
  再把 keybindings.json 终端那段补齐 `<C-h>` / `<C-l>` 即可。（`Ctrl+J` 不用加，
  它已被 VSCode 默认占为开关面板。）
- **`<leader>e` 为什么不完全是 LazyVim 的「文件树开关」**：你这版 VSCode **没有 `toggleExplorer` 命令**
  （已把本机 1839 个命令 ID 全筛过），只有 `workbench.view.explorer`（仅显示/聚焦）和
  `workbench.action.toggleSidebarVisibility`（真开/关）。现在 `<leader>e` 用的是后者：
  侧边栏开着就关、关着就开。**唯一区别**是「关着时打开」会恢复侧边栏上一次的视图——
  如果上次是 SCM/扩展，就用 `<leader>E` 把文件树换回来。
  想要 100% 只切文件树，得把整个 leader 键树从 settings.json 搬到 keybindings.json，
  再用 `explorerViewletVisible && sideBarVisible` 条件分流；但那样 `space` 会变成 VSCode 层的
  chord 前缀，反过来把 settings.json 里所有 `<leader>xx` 全吃掉，所以没有采用。
- **`<leader>sw` 搜索光标下的词**：VSCode 的全局搜索默认不会自动填入光标词。若想让
  `<leader>sw` 真的带上词，在 settings.json 加 `"search.seedWithNearestWord": true`
  ——代价是 `Ctrl+Shift+F` 也会默认带上光标词/选区。
- **`<S-h>`/`<S-l>` 不生效时**：VSCodeVim 个别版本对 `<S-h>` 记法解析成大写 `H`，
  把 `"before": ["<S-h>"]` 改成 `"before": ["H"]` 即可（`<S-l>` → `"L"`）。
  注意这会覆盖 vim 原生的「跳到屏幕顶/底行」——LazyVim 本来也是这么覆盖的。
- **`ctrl+/` 让位了**：它原本是 VSCode 的切换行注释，现在归终端（和 LazyVim 一致）。
  注释用 `gcc` / `gc`（VSCodeVim 原生支持）。
- **`files.autoSave: "afterDelay"`**：你开着自动保存，这点和 vim 习惯差别较大，
  如果想让 `:w` 有意义可以考虑关掉（与本次按键改造无关，仅提示）。
- 没有 which-key，键位不好记。本文件第三节就是一份对照表，也可以在公司/家里直接查
  `Ctrl+Shift+P` → **Preferences: Open Keyboard Shortcuts** 搜 `vim.normalMode`——但注意
  VSCodeVim 的 `vim.*ModeKeyBindings` **不会**出现在快捷键 UI 里，只能查本文件。

---

## 八、这份配置的可靠性说明

- LazyVim 默认键位取自 `www.lazyvim.org/keymaps` 与
  `LazyVim/lua/lazyvim/config/keymaps.lua`（main 分支），并对照本机 `lazyvim.json` 里
  实际启用的 extras（`dap.core`、`neogen`、`lang.*`、`linting.eslint` 等）取交集。
- 所有 VSCode 命令 ID 都**逐个在你这台机器的实际安装里验证过**：
  `F:\app_program\work\Microsoft VS Code\7debcd0e2a\resources\app\out\vs\workbench\workbench.desktop.main.js`
  与内置 `git` 扩展的 `package.json`（共 1839 个命令 ID），没有凭记忆写。
  被验证筛掉的写法例如 `workbench.view.problems`（正确是 `workbench.action.problems.focus`）、
  `workbench.action.nextTab`（VSCode 没有 tab 命令）、`editor.action.codelens.action`。
- VSCodeVim 的 mode 上下文取自本机 `vscodevim.vim-1.32.4`：
  `vim.active` 与 `vim.mode`（取值 `Normal` / `Insert` / `Visual` / `VisualLine` /
  `VisualBlock` / `Replace` / `CommandlineInProgress` / `SearchInProgressMode`），
  `vim.mode` 由 `VSCodeContext.set("vim.mode", Mode[...])` 设置。
- 跨区域移动用的是 `workbench.action.navigate*`：它的行为是从本机 Workbench 源码里
  读出来的（`JVe.run`：编辑器有焦点时先 `navigateAcrossEditorGroup`，该方向没有分屏
  才 `getVisibleNeighborPart` 回落到相邻区域），并确认了它调用 `findGroup` 时**没传
  wrap 参数**，即单个编辑组时不会环绕、能正确回落 —— 这是这个方案能成立的前提。
- 终端里按键归谁，同样是从源码读出来的：`attachCustomKeyEventHandler` 里只有
  `inChordMode || (chord && allowChords) || (!sendKeybindingsToShell && 命中命令 && shouldCommandSkipShell(命令))`
  才会 `preventDefault`，而 `commandsToSkipShell` 的内置默认列表共 159 条
  （`focusActiveEditorGroup`、`navigateLeft/Right/Up/Down`、`togglePanel` 在列；
  `focusLeftGroup`、`focusSideBar`、`focusPanel` **不在**）——所以终端里只接管
  `<C-k>` 是有依据的，不是猜的。
