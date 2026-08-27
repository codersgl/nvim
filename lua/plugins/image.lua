-- image.nvim:在 nvim 里显示图片(sixel 图形协议)
-- Windows Terminal 自 1.20 起(conhost 2024-07 合并 #17421)支持 sixel,
-- 不支持 kitty 图形协议(microsoft/terminal#8389 仍在 backlog)
-- 依赖:ImageMagick CLI 的 sixel 编码器(本机 6.9.11 已确认支持 SIXEL 格式)
-- 功能:
--   1. 直接打开 .png/.jpg 等图片文件时在编辑器里显示(hijack_file_patterns)
--   2. markdown 笔记里内嵌预览图片(markdown 集成)
return {
  {
    "3rd/image.nvim",
    build = false, -- 不构建 magick rock,用 magick_cli(调用系统 ImageMagick)
    opts = {
      backend = "sixel",
      processor = "magick_cli",
      hijack_file_patterns = { "*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.avif" },
      integrations = {
        markdown = {
          enabled = true,
          only_render_image_at_cursor = false,
          filetypes = { "markdown", "vimwiki" },
        },
      },
    },
  },
}
