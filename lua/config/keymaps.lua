-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
local map = vim.keymap.set

map("i", "jk", "<Esc>")

-- 终端缓冲区里也用 jk 回到 Normal 模式（和 insert 模式保持一致）
-- 为什么这一个就够: t 模式是全局映射，:terminal 的终端 buffer、snacks 的浮动
--   终端、其它插件的终端全都生效；Esc 完全不碰，codex / claude code 的“Esc 中断”
--   不受影响，也不用记 <C-\><C-n>。
-- 代价: j 是 jk 的前缀，终端里单独敲 j 会等 timeoutlen 才发给程序（LazyVim 默认 300ms）。
map("t", "jk", "<C-\\><C-n>", { desc = "退出终端模式" })

-- ============================================================
-- 把图片复制到 Windows 剪贴板（WSL 环境）—— 方向: nvim 图片 → Windows 剪贴板
-- 用法:
--   :CopyImage                   复制当前 buffer 的图片文件（若是图片）
--   :CopyImage <路径>            复制指定路径的图片
--   <leader>yi (普通模式)        复制当前 buffer 的图片文件
--   gI (普通模式)                同上，备用键
--   <leader>yi (可视模式)        复制选中区域代表的图片路径
--
-- 为什么用 .ps1: WSL 里 clip.exe 只能传文本; 图片必须走 Windows 自带
-- PowerShell [System.Windows.Forms.Clipboard]::SetImage()。零安装。
-- ★坑(实锤): 内联 -Command "...$img..." 在 vim.fn.system 里会经 sh -c 展开
-- $img 成空 → SetImage 空参 ParserError。正解=写临时 .ps1 再 -File 执行。
-- ★键位对比 explorer: 这里是普通 buffer, 没有单键 y 的 nowait 截断,
--   所以 <leader>yi 三击键是安全的; 而 explorer 里单键 y 会截断 yi(死键)。
-- ============================================================

local function is_image(fname)
  local ext = fname:match("%.([^.]+)$")
  if not ext then
    return false
  end
  ext = ext:lower()
  return ext == "png"
    or ext == "jpg"
    or ext == "jpeg"
    or ext == "gif"
    or ext == "bmp"
    or ext == "webp"
    or ext == "ico"
    or ext == "tiff"
end

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
  if vim.fn.filereadable(path) ~= 1 then
    vim.notify("CopyImage: 文件不可读 " .. path, vim.log.levels.ERROR)
    return
  end
  -- WSL 路径 -> Windows 路径
  local win_path = vim.fn.system("wslpath -w " .. vim.fn.shellescape(path)):gsub("\n", "")
  if win_path == "" or win_path:find("not found") then
    vim.notify("CopyImage: 无法解析路径 " .. path, vim.log.levels.ERROR)
    return
  end
  -- 写临时 .ps1 再执行，避开 vim.fn.system 经 shell 展开 $ 的坑
  local ps1_path = vim.fn.tempname() .. ".ps1"
  local ps = [[Add-Type -AssemblyName System.Windows.Forms,System.Drawing
$img=[System.Drawing.Image]::FromFile('%s')
[System.Windows.Forms.Clipboard]::SetImage($img)
$img.Dispose()
Write-Output 'SET_OK'
]]
  local file = io.open(ps1_path, "w")
  if not file then
    vim.notify("CopyImage: 无法创建临时 ps1", vim.log.levels.ERROR)
    return
  end
  file:write(string.format(ps, win_path))
  file:close()
  local win_ps1 = vim.fn.system("wslpath -w " .. vim.fn.shellescape(ps1_path)):gsub("\n", "")
  local cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File " .. vim.fn.shellescape(win_ps1)
  local out = vim.fn.system(cmd)
  -- 清理临时文件
  os.remove(ps1_path)
  if out:find("SET_OK") then
    vim.notify("已复制图片到 Windows 剪贴板: " .. path, vim.log.levels.INFO)
  else
    vim.notify("CopyImage 失败: " .. out, vim.log.levels.ERROR)
  end
end

-- 普通模式/命令: 复制当前 buffer 文件(若是图片)
local function copy_current()
  local p = vim.fn.expand("%:p")
  if p == "" then
    vim.notify("CopyImage: 当前 buffer 无文件", vim.log.levels.WARN)
    return
  end
  M.copy_image(p)
end

-- 命令（支持范围 + 可选参数）
vim.api.nvim_create_user_command("CopyImage", function(args)
  if args.args and #args.args > 0 then
    M.copy_image(vim.fn.expand(args.args))
  else
    copy_current()
  end
end, { nargs = "?", range = true, desc = "Copy image to Windows clipboard" })

-- 普通模式：<leader>yi 复制当前 buffer 图片；gI 备用
map("n", "<leader>yi", copy_current, { desc = "Copy image to Windows clipboard" })
map("n", "gI", copy_current, { desc = "Copy image to Windows clipboard" })

-- 可视模式：把选中区域当图片路径复制
map("v", "<leader>yi", function()
  local sel = table.concat(vim.fn.getline("'<", "'>"), " ")
  if sel == "" then
    vim.notify("CopyImage: 可视区域内没有图片路径", vim.log.levels.WARN)
    return
  end
  M.copy_image(sel)
end, { desc = "Copy image (selection) to clipboard" })

-- ============================================================
-- 用 Windows 默认程序打开文件 / 图片
-- Neovide 没有内联图片支持，这就是 Neovide 里的看图方式。
-- 为什么不用 vim.ui.open(): WSL 里的 xdg-open 没有 Windows 转发逻辑
-- (本机未装 wslu/wslview)，直接 explorer.exe + wslpath 最稳；非 WSL 环境自动退回。
-- 用法: <leader>xo 打开当前文件；可视模式选中路径后 <leader>xo 打开它
-- ============================================================
local function open_external(path)
  path = vim.fn.expand(path or "%:p")
  if path == "" or vim.fn.filereadable(path) == 0 then
    vim.notify("open_external: 找不到文件 " .. path, vim.log.levels.WARN)
    return
  end
  if vim.fn.executable("wslpath") == 1 and vim.fn.executable("explorer.exe") == 1 then
    local win_path = vim.fn.system({ "wslpath", "-w", path }):gsub("%s+$", "")
    vim.system({ "explorer.exe", win_path }, { detach = true })
  else
    vim.ui.open(path)
  end
end

map("n", "<leader>xo", function()
  open_external("%:p")
end, { desc = "用系统程序打开当前文件" })

map("x", "<leader>xo", function()
  local region_type = vim.fn.mode() == "V" and "V" or "v"
  local sel = table.concat(vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = region_type }), "")
  open_external(sel)
end, { desc = "用系统程序打开选中的路径" })

-- 图片内联渲染开关（只在支持 sixel/kitty 的终端里有效；Neovide 下 image.nvim 已禁用）
map("n", "<leader>uo", function()
  local ok, image = pcall(require, "image")
  if not ok then
    vim.notify("image.nvim 未加载（Neovide 下已禁用，请用 <leader>xo 打开图片）", vim.log.levels.WARN)
    return
  end
  if image.is_enabled() then
    image.disable()
    vim.notify("图片内联渲染: 关闭")
  else
    image.enable()
    vim.notify("图片内联渲染: 开启")
  end
end, { desc = "切换图片内联渲染" })

return M
