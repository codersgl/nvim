-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)

-- 中文用户:去掉 LazyVim 默认给文本类开启的英文拼写检查。
-- 原因:LazyVim 的 wrap_spell group 会在 markdown/text/gitcommit 等文件里设 spell=true,
-- 而 spelllang=en 会把整篇中文判为拼写错误 → 红线铺满。这里删掉该 group(保留 wrap 自动折行)。
vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

local text_filetypes = { "text", "plaintex", "typst", "gitcommit", "markdown" }

-- 重新给文本类只开折行 wrap、不开拼写检查 spell。
vim.api.nvim_create_autocmd("FileType", {
  pattern = text_filetypes,
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.spell = false
  end,
})

-- 兜底:处理「启动 nvim 时就直接打开了 md/文本文件」的情况——此时 FileType
-- 事件早于本配置加载,LazyVim 的 spell=true 已经生效,删 group 不会清当前窗口,
-- 需要显式重置当前窗口的 spell(spell 是 window-local 选项,用 opt_local)。
vim.opt_local.spell = false
