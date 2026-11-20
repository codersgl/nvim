-- image.nvim：在支持图形协议的终端里内联显示图片（sixel 后端）
--
-- 后端与依赖：
--   * sixel 后端 -> Windows Terminal / WezTerm / foot / xterm 等支持 sixel 的终端
--   * ImageMagick：IM7 用 `magick`，IM6 用 `convert`，插件会自动探测（本机是 IM6）
--
-- ⚠️ Neovide 不实现 sixel / kitty 图形协议（neovide#2088 仍开放），
--    所以在 Neovide 下直接禁用整个插件，避免白跑和残留转义序列。
--    Neovide 里看图请用 <leader>xo（见 lua/config/keymaps.lua，调系统默认看图器）。
return {
  {
    "3rd/image.nvim",
    enabled = not vim.g.neovide,
    build = false, -- 不编译 magick rock，直接用系统 ImageMagick CLI
    opts = {
      backend = "sixel",
      processor = "magick_cli",

      -- 尺寸上限（单位：单元格），超出按比例缩放，避免大图占满窗口
      max_width = 100,
      max_height = 30,
      max_width_window_percentage = 100,
      max_height_window_percentage = 50,

      -- sixel 是把图"画"在终端上：别的窗口压上来时必须清掉，否则会残留糊在文字上
      window_overlap_clear_enabled = true,
      window_overlap_clear_ft_ignore = {
        "cmp_menu",
        "cmp_docs",
        "snacks_notif",
        "scrollview",
        "scrollview_sign",
      },

      -- 直接打开图片文件时在编辑器里显示（gif 只显示第一帧）
      hijack_file_patterns = {
        "*.png",
        "*.jpg",
        "*.jpeg",
        "*.gif",
        "*.webp",
        "*.avif",
        "*.bmp",
        "*.tiff",
      },

      integrations = {
        markdown = {
          enabled = true,
          filetypes = { "markdown", "vimwiki" },
          -- sixel 性能一般，官方推荐的省力组合：只在光标所在图片上渲染 + popup 模式
          only_render_image_at_cursor = true,
          only_render_image_at_cursor_mode = "popup",
          clear_in_insert_mode = true, -- 进插入模式先清图，打字不闪
          download_remote_images = false, -- 本地笔记不联网拉图，避免卡顿
          floating_windows = false,
        },
      },
    },
  },
}
