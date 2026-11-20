-- ============================================================================
-- 配色方案：默认 Carbonfox（nightfox.nvim），另有 OneDark / TokyoNight 全系列
-- ============================================================================
-- 切换方式（装了就能用，不用改配置）：
--   <leader>uC               Snacks 选择器，带实时预览（光标上下移动即改色，回车确认）
--   :Theme                   同上，无参数打开选择器
--   :Theme carbonfox         直接切到某套配色，支持 Tab 补全
-- 选过的主题会被记住，重启沿用（见下面「主题记忆」）；想回默认删掉状态文件即可。
--
-- 一共 18 套，都是「一种长相一个名字」，选择器里一眼能分辨：
--   nightfox   7 套 flavor：carbonfox / nightfox / dayfox / dawnfox / duskfox /
--                           nordfox / terafox
--   onedark    7 种风格：    onedark-darker（最深）/ onedark-dark / onedark-cool /
--                           onedark-deep / onedark-warm / onedark-warmer /
--                           onedark-light（浅色）
--   tokyonight 4 种风格：    tokyonight-night / tokyonight-storm /
--                           tokyonight-moon / tokyonight-day（浅色）
-- 两个浅色主题（onedark-light / tokyonight-day）会把 background 切成 light，
-- 切回任一深色主题时由各插件自己改回 dark。不要浅色的话：删掉
-- colors/onedark-light.lua，并把 tokyonight-day 加进下面的 HIDDEN 即可。
--
-- ── OneDark 的 7 种风格为什么要单独做壳文件 ─────────────────────────────────
-- onedark.nvim 只注册了 onedark 一个 colorscheme 名字，6 种风格是 options.style
-- 这个「选项」而不是 6 个「名字」，所以选择器只能列出 onedark 一项、切不出风格。
-- 解法照抄 tokyonight 的做法（它的 tokyonight-day/-storm/-moon/-night 就是
-- 一种风格一个 colors/ 入口文件）：在 colors/ 下给每种风格放一个同名壳文件。
-- stdpath("config") 本来就在 rtp 里，于是 :colorscheme onedark-warm 能查到它，
-- 而选择器与 :Theme 的补全都是 getcompletion("", "color") 扫出来的，自动就有，
-- 整个切换链路不需要任何特殊分支。
-- 对比：tokyonight 本身就按这个套路注册好了 4 个具名入口，所以它不需要壳文件。
--
-- 具体实现收在 lua/config/onedark_styles.lua（壳文件只转调它），三个坑都记在那里：
--   1. ★不能用 require("onedark").load()：它就是 :colorscheme onedark，而 Neovim
--      会屏蔽「在 colorscheme 文件里再调 :colorscheme」的重入调用——静默跳过、
--      不报错、不改高亮。迷惑点在于壳文件最后一行照常执行，于是 g:colors_name
--      已经变成 onedark-warm、画面却还是上一个配色，看着像"切了"，其实没切。
--      正解是直接调插件的 colorscheme()（公开 API）。
--   2. 必须先清 onedark.* 的模块缓存，并按风格把 background 钉对：调色板是在
--      onedark.colors 加载时就算好的，而 background 又会被它的「light 分支」劫持。
--   3. 最后要把 g:colors_name 从 "onedark" 改回 "onedark-<style>"，
--      否则「主题记忆」只会记下 "onedark"，重启就把风格丢了。
--
-- 中文相关取舍：nightfox 的 styles 默认全为 "NONE"（不加斜体），正好符合
--   「中文字体多是合成斜体、一斜就发虚」的要求；这里显式列出来当文档用。
-- ============================================================================

local DEFAULT_THEME = "carbonfox" -- 启动兜底配色
local STATE_FILE = vim.fn.stdpath("state") .. "/last_colorscheme" -- 记住上次选择

-- ── 主题记忆 ────────────────────────────────────────────────────────────────
-- 为什么记在 VimLeavePre，而不是监听 ColorScheme：
--   <leader>uC 是「实时预览」选择器，光标每动一格就 :colorscheme 一次。
--   若在 ColorScheme 里落盘，预览过、但最后按 Esc 放弃的主题也会被记住。
--   退出时只读一次 vim.g.colors_name，记下的必然是真正生效的那套。
-- 失效兜底：记录的名字可能来自已删除/改名的插件，应用失败就回退默认主题，
--   不让一次失败的读取把启动搞报错。
-- 恢复默认：删掉 <stdpath("state")>/last_colorscheme。
local function read_last_theme()
  local fd = io.open(STATE_FILE, "r")
  if not fd then
    return nil
  end
  local name = fd:read("*l")
  fd:close()
  if name and name ~= "" then
    return name
  end
  return nil
end

local function apply_theme(name)
  if not pcall(vim.cmd.colorscheme, name) then
    pcall(vim.cmd.colorscheme, DEFAULT_THEME)
  end
end

vim.api.nvim_create_autocmd("VimLeavePre", {
  group = vim.api.nvim_create_augroup("UserColorschemePersist", { clear = true }),
  callback = function()
    local name = vim.g.colors_name
    if name and name ~= "" then
      vim.fn.mkdir(vim.fn.stdpath("state"), "p")
      pcall(vim.fn.writefile, { name }, STATE_FILE)
    end
  end,
})

-- ── 配色清单：只列「一种长相一个名字」的条目 ─────────────────────────────────
-- 隐去两类名字：
--   1. Neovim 内置的 28 套（$VIMRUNTIME/colors），它们不属于任何插件
--   2. 两个「裸名」，它们都不是独立长相：
--      * onedark —— 长相取决于 vim.g.onedark_config.style，也就是「上次选过
--        哪种风格」，同一个名字在不同时候是不同颜色，没法当选项
--      * tokyonight —— load() 之后它自己就把 g:colors_name 写成
--        tokyonight-<style>，裸名只是配置里那个风格的别名，跟具名条目重复
--      （手敲 :colorscheme onedark / tokyonight 仍然可用）
local HIDDEN = { onedark = true, tokyonight = true }

local function hidden_colorschemes()
  local set = {}
  for name in pairs(HIDDEN) do
    set[name] = true
  end
  local runtime = vim.env.VIMRUNTIME
  if runtime and runtime ~= "" then
    for name in vim.fs.dir(runtime .. "/colors") do
      set[vim.fn.fnamemodify(name, ":t:r")] = true
    end
  end
  return set
end

local function plugin_colorschemes()
  local hidden = hidden_colorschemes()
  local out = {}
  for _, name in ipairs(vim.fn.getcompletion("", "color")) do
    if not hidden[name] then
      out[#out + 1] = name
    end
  end
  table.sort(out)
  return out
end

-- :Theme —— 命令行入口，方便脚本化 / 不想记快捷键时用
-- pcall 包住：spec 文件万一被 lazy 重复导入，这里不会因「命令已存在」而报错
pcall(vim.api.nvim_create_user_command, "Theme", function(args)
  if args.args == "" then
    if package.loaded["snacks"] then
      Snacks.picker.colorschemes()
    else
      vim.notify("Snacks 还没加载，先 :Theme <配色名> 顶一下", vim.log.levels.WARN)
    end
  else
    apply_theme(args.args)
  end
end, {
  nargs = "?",
  desc = "切换配色方案（无参数 = 打开选择器）",
  complete = function()
    return plugin_colorschemes()
  end,
})

return {
  -- 主配色：Carbonfox
  {
    "EdenEast/nightfox.nvim",
    lazy = false, -- 必须立即加载：否则 colors/ 不在 rtp 里，选择器选中会报 E185
    priority = 1000, -- 和 onedark 一起排在 start 插件最前面
    opts = {
      options = {
        transparent = false, -- 透明统一交给 options.lua 的 neovide_opacity，配色层不插手
        dim_inactive = false, -- 失焦窗口不压暗：中文行压暗后更糊
        terminal_colors = true, -- :terminal 里的 16 色跟随主题
        styles = {
          comments = "NONE",
          conditionals = "NONE",
          constants = "NONE",
          functions = "NONE",
          keywords = "NONE",
          numbers = "NONE",
          operators = "NONE",
          preprocs = "NONE",
          strings = "NONE",
          types = "NONE",
          variables = "NONE",
        },
      },
    },
  },

  -- 备选配色：OneDark 全系列（7 种风格，各自的入口在 colors/onedark-*.lua）
  -- 这里的 opts 是「公共底座」：code_style / diagnostics 等对 7 种风格一视同仁，
  -- 壳文件里的 setup 只覆盖 style，靠 onedark 内部的 force 合并保留这些设置。
  -- style 只在「没有任何壳文件介入」时生效（例如手敲 :colorscheme onedark），
  -- 取 darker 是沿用你原来的选择，最深、对比最强。
  -- 7 种风格：darker(最深) / dark(默认) / cool / deep / warm / warmer / light(浅色)
  {
    "navarasu/onedark.nvim",
    lazy = false, -- 同样立即加载，选择器才能随时切回来
    priority = 1000,
    opts = {
      style = "darker",
      transparent = false, -- 透明背景用 g:neovide_opacity（见 lua/config/options.lua）；
      -- 此处改 true 只是让 Normal.bg 为空，Neovide 仍会填充画布，不能单独实现透明
      code_style = {
        comments = "none",
        keywords = "none",
        functions = "none",
        strings = "none",
        variables = "none",
      },
      diagnostics = {
        darker = true, -- 诊断背景比正文暗，避免中文行被色块压住
        background = true,
      },
    },
  },

  -- 备选配色：TokyoNight 4 种风格
  -- 和 onedark 不同，tokyonight 每种风格都注册了独立名字（tokyonight-night /
  -- -storm / -moon / -day），入口直接 require("tokyonight").load({style=...})，
  -- 不走 :colorscheme，所以既不需要壳文件、也没有 onedark 那个重入坑。
  -- 下面 opts 是「公共底座」：load() 每次都 force 合并，只覆盖 style。
  {
    "folke/tokyonight.nvim",
    lazy = false, -- 同前：不立即加载的话 colors/ 不在 rtp，选择器选中会报 E185
    priority = 1000,
    opts = {
      style = "moon", -- 裸名 tokyonight 解析成的风格（该裸名已从列表隐去）
      light_style = "day", -- background 为 light 时裸名 tokyonight 用的风格
      transparent = false, -- 透明统一交给 options.lua 的 neovide_opacity
      terminal_colors = true,
      dim_inactive = false, -- 失焦窗口不压暗，照顾中文
      styles = {
        -- ★必须显式写 italic = false：默认是 { italic = true }，而合并走的是
        --   vim.tbl_deep_extend("force")，写空表 {} 是清不掉 italic 的
        comments = { italic = false },
        keywords = { italic = false },
        functions = {},
        variables = {},
        sidebars = "dark", -- 侧栏/浮窗用更暗背景，与整体深色取向一致
        floats = "dark",
      },
    },
  },

  -- LazyVim 16 的核心 colorscheme.lua 自带 catppuccin 的 spec，
  -- 必须显式禁用，否则它会被安装（即使不加载也会占磁盘）
  { "catppuccin/nvim", enabled = false },

  -- 启动时用哪套：优先上次记住的，没有则 Carbonfox（apply_theme 内已含失效回退）
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = function()
        apply_theme(read_last_theme() or DEFAULT_THEME)
      end,
    },
  },

  -- <leader>uC 默认会把 Neovim 自带的 28 个内置配色也列出来（它们不是插件），
  -- 这里覆盖成只列 13 套具名配色（见文件顶部说明）
  {
    "folke/snacks.nvim",
    optional = true,
    keys = {
      {
        "<leader>uC",
        function()
          local hidden = hidden_colorschemes()
          Snacks.picker.colorschemes({
            transform = function(item)
              if hidden[item.text] then
                return false -- 丢弃内置配色与裸名 onedark
              end
              return item
            end,
          })
        end,
        desc = "Colorscheme (仅插件)",
      },
    },
  },
}
