-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
local map = vim.keymap.set

map("i", "jk", "<Esc>")

---@diagnostic disable-next-line: redefined-local
local map = vim.keymap.set

-- ============================================================
-- 把图片复制到 Windows 剪贴板（WSL 环境）
-- 用法:
--   :CopyImage                      复制当前 buffer 的图片文件
--   :CopyImage <路径>               复制指定路径的图片
--   :'<,'>CopyImage  或 <leader>yi   可视模式选中图片路径后复制
--
-- WSL 里 clip.exe 只支持文本，图片必须走 Windows 自带 PowerShell
-- (System.Windows.Forms.Clipboard.SetImage)，零安装。
-- 已验证可双向收发（本机 Win/WSL 实测 SET_OK + GET_OK）
-- ============================================================

local function is_image(fname)
  local ext = fname:match("%.([^.]+)$")
  if not ext then
    return false
  end
  ext = ext:lower()
  return ext == "png" or ext == "jpg" or ext == "jpeg" or ext == "gif" or ext == "bmp"
    or ext == "webp" or ext == "svg" or ext == "ico" or ext == "tiff"
end

-- 导出,便于 snacks-img-yank.lua 复用
local M = {}
function M.copy_image(path)
  if not path or path == "" then
    vim.notify("CopyImage: 没有图片路径", vim.log.levels.WARN)
    return
  end
  if not is_image(path) then
    vim.notify("CopyImage: 不是图片文件 (" .. path .. ")", vim.log.levels.WARN)
    return
  end
  -- WSL 路径 -> Windows 路径
  local win_path = vim.fn.system("wslpath -w " .. vim.fn.shellescape(path)):gsub("\n", "")
  if win_path == "" or win_path:find("not found") then
    vim.notify("CopyImage: 无法解析路径 " .. path, vim.log.levels.ERROR)
    return
  end
  -- 写临时 .ps1 再执行，避开 vim.fn.system 经 shell 展开 $ 的坑
  -- (实锤: 双引号内联 Command 时 $img 被外层 shell 吃掉, SetImage 空参报错)
  local ps1_path = vim.fn.tempname() .. ".ps1"
  local ps = ([[Add-Type -AssemblyName System.Windows.Forms,System.Drawing
$img=[System.Drawing.Image]::FromFile('%s')
[System.Windows.Forms.Clipboard]::SetImage($img)
$img.Dispose()
Write-Output 'SET_OK'
]])
  local file = io.open(ps1_path, "w")
  if not file then
    vim.notify("CopyImage: 无法创建临时 ps1", vim.log.levels.ERROR)
    return
  end
  file:write(string.format(ps, win_path))
  file:close()
  local win_ps1 = vim.fn.system("wslpath -w " .. vim.fn.shellescape(ps1_path)):gsub("\n", "")
  local cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File "
    .. vim.fn.shellescape(win_ps1)
  local out = vim.fn.system(cmd)
  -- 清理临时文件
  os.remove(ps1_path)
  if out:find("SET_OK") then
    vim.notify("已复制图片到 Windows 剪贴板: " .. path, vim.log.levels.INFO)
  else
    vim.notify("CopyImage 失败: " .. out, vim.log.levels.ERROR)
  end
end

local function current_or_arg(args)
  if args and args.args and #args.args > 0 then
    return vim.fn.expand(args.args)
  end
  return vim.fn.expand("%:p")
end

-- 命令（支持范围 + 可选参数）
vim.api.nvim_create_user_command("CopyImage", function(args)
  M.copy_image(current_or_arg(args))
end, { nargs = "?", range = true, desc = "Copy image to Windows clipboard" })

-- 可视模式下选中图片路径后一键复制
map("v", "<leader>yi", function()
  local sel = table.concat(vim.fn.getline("'<", "'>"), " ")
  if sel == "" then
    vim.notify("CopyImage: 可视区域内没有图片路径", vim.log.levels.WARN)
    return
  end
  M.copy_image(sel)
end, { desc = "Copy image (selection) to clipboard" })

return M
