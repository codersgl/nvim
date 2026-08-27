-- 在 Snacks explorer 里把当前文件图片复制到 Windows 剪贴板
-- 用法: <leader>e 打开 explorer -> 光标停在图片上 -> 按 <leader>y
-- 底层复用 keymaps.lua 里的 copy_image（走 PowerShell SetImage，已验证双向可收发）
--
-- 原理（对齐 snacks 源码，非凭记忆）:
--   - explorer 的键绑定在 picker/config/sources.lua 的 M.explorer.win.list.keys 里,
--     ["y"] = "explorer_yank" 拷贝路径
--   - action 实际是 require("snacks.explorer.actions").actions 里的函数,
--     入参 picker, 用 picker:selected({fallback=true}) 拿当前项,
--     再 Snacks.picker.util.path(item) 拿绝对路径
return {
  {
    "folke/snacks.nvim",
    opts = function()
      local Snacks = require("snacks")
      -- 注入一个新 action
      local actions = require("snacks.explorer.actions").actions
      actions.explorer_yank_image = function(picker)
        local files = {}
        if vim.fn.mode():find("^[vV]") then
          picker.list:select()
        end
        for _, item in ipairs(picker:selected({ fallback = true })) do
          table.insert(files, Snacks.picker.util.path(item))
        end
        picker.list:set_selected()
        -- config.keymaps 由 VeryLazy 自动加载; 用 pcall 兜底(极早打开 explorer 时可能还没加载)
        local ok, img = pcall(function()
          return require("config.keymaps").copy_image
        end)
        for _, path in ipairs(files) do
          if not path or path == "" then
            vim.notify("复制图片: 未找到当前文件", vim.log.levels.WARN)
          elseif not ok then
            vim.notify("复制图片: config.keymaps 未加载", vim.log.levels.WARN)
          else
            img(path)
          end
        end
      end
      return {
        picker = {
          sources = {
            explorer = {
              -- ★键必须放 win.list.keys（不是顶层 keys）。
              -- 注意：snacks 对 opts.picker.sources.explorer 的合并是深合并，
              -- 但 LazyVim 的 snacks_explorer extra 只有 opts={explorer={}}，
              -- 若这里只给 win.list.keys={我的键}，会整个覆盖默认的 win 结构，
              -- 导致默认键(y/h/l/a/d/r...)全丢。因此必须把默认 explorer keys 取出来
              -- 用 tbl_deep_extend 合并，保留全部默认键再追加。
              win = {
                list = {
                  keys = vim.tbl_deep_extend(
                    "force",
                    {}, -- 目标：把默认键 + 我的键复制进去
                    (function()
                      -- 读 snacks 源码里的默认 explorer win.list.keys
                      local sources = require("snacks.picker.config.sources")
                      local ex = sources.M and sources.M.explorer or sources.explorer
                      return (ex and ex.win and ex.win.list and ex.win.list.keys) or {}
                    end)(),
                    -- 我的自定义键（不与默认的 "y" 冲突；不能再用 "yi"——
                    --   win.lua 强制 nowait=true, 单键 "y" 会先触发复制路径, "i" 永远收不到）
                    { ["<leader>y"] = { "explorer_yank_image", mode = { "n", "x" } } }
                  ),
                },
              },
            },
          },
        },
      }
    end,
  },
}
