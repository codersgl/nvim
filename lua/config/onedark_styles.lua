-- ============================================================================
-- onedark 6 种风格的统一入口（供 colors/onedark-*.lua 调用）
-- ============================================================================
-- 背景：onedark.nvim 只注册了 onedark 一个 colorscheme 名字，6 种风格是
-- options.style 这个选项。为了让 :colorscheme onedark-warm / <leader>uC /
-- :Theme 都能按名字直接选，在 colors/ 下给每种风格放了一个壳文件，
-- 壳文件只负责转调这里的 apply()。
--
-- ★ 最关键的一条：这里【绝对不能】用 require("onedark").load()
--   load() 的实现就是 vim.cmd("colorscheme onedark")，而 Neovim 会屏蔽
--   「在 colorscheme 文件里再调 :colorscheme」这种重入调用：静默跳过、
--   不报错、不改任何高亮。表现极具迷惑性——g:colors_name 变成了 onedark-warm
--   （壳文件最后一行照样执行），但画面还是上一个配色的颜色，看起来"切了却没变"。
--   所以这里直接调插件公开的 colorscheme()，其注释写明 same as ':colorscheme onedark'。
-- ============================================================================

local M = {}

--- 应用 onedark 的某个风格，并把 g:colors_name 钉成 onedark-<style>
---@param style string 'dark'|'darker'|'cool'|'deep'|'warm'|'warmer'|'light'
function M.apply(style)
  -- 1) 清模块缓存。onedark.colors 在模块加载时就把调色板选好了，
  --    onedark.highlights 也在加载时把它抓成了 upvalue；不清缓存就会一直用
  --    第一次那套，出现「切风格没反应」。这段用的是插件自带 colors/onedark.lua
  --    的同一个模式（顺带也会把本文件从缓存里清掉，无害，下次 require 重建）。
  for name in pairs(package.loaded) do
    if name:match(".*onedark.*") then
      package.loaded[name] = nil
    end
  end

  -- 2) background 必须先钉对。onedark 的 colorscheme() 里有
  --    「background 是 light 就把 style 强制成 light」的分支：深色风格先设 dark
  --    才不会被它劫走；light 风格则要靠它把 style 锁在 light。
  vim.o.background = style == "light" and "light" or "dark"

  -- 3) setup 只传 style：内部是 tbl_deep_extend('force') 合并，
  --    plugins/theme.lua 里 opts 配的 code_style / diagnostics 会被保留，
  --    不会被打回默认值。
  require("onedark").setup({ style = style })

  -- 4) 应用高亮（是 colorscheme() 而不是 load()，原因见文件顶部）
  require("onedark").colorscheme()

  -- 5) 上一步会把 g:colors_name 写成 "onedark"，改回带后缀的名字。
  --    否则主题记忆只会记住 "onedark"，重启就把风格丢了。
  vim.g.colors_name = "onedark-" .. style
end

return M
