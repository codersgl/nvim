return {
  -- 1. 安装 Catppuccin 插件
  {
    "catppuccin/nvim",
    name = "catppuccin", -- 给插件指定别名，方便后续调用
    priority = 1000, -- 提高优先级，确保主题先于其他插件加载，避免样式错乱
    lazy = false,
    opts = {
      -- 2. Catppuccin 核心配置（可根据个人喜好修改）
      flavour = "mocha", -- 选择主题风格，可选：mocha(默认/深棕)、macchiato(深灰)、frappe(浅灰)、latte(浅色)
      transparent_background = false, -- 是否开启透明背景（true 为开启）
      show_end_of_buffer = false, -- 隐藏缓冲区末尾的 ~ 符号
      term_colors = true, -- 启用终端颜色适配
      dim_inactive = {
        enabled = false, -- 暗淡非活动窗口
        shade = "dark",
        percentage = 0.15,
      },
      -- 3. 集成 LazyVim 常用组件（确保样式兼容）
      integrations = {
        alpha = true, -- LazyVim 启动页
        cmp = true, -- 自动补全
        gitsigns = true, -- Git 状态提示
        illuminate = true, -- 代码高亮标注
        indent_blankline = { -- 缩进线
          enabled = true,
          colored_indent_levels = false,
        },
        lsp_trouble = true, -- LSP 错误提示
        mason = true, -- LSP 安装工具
        mini = true, -- LazyVim 内置迷你组件
        native_lsp = { -- 原生 LSP
          enabled = true,
          underlines = {
            errors = { "undercurl" },
            hints = { "undercurl" },
            warnings = { "undercurl" },
            information = { "undercurl" },
          },
        },
        navic = { enabled = true, custom_bg = "lualine" }, -- 导航栏
        neotree = true, -- 文件树
        noice = true, -- 消息提示
        notify = true, -- 通知弹窗
        telescope = true, -- 搜索框
        treesitter = true, -- 语法高亮
        which_key = true, -- 快捷键提示
        -- 若你使用其他插件，可在此添加对应集成配置
      },
    },
    config = function(_, opts)
      -- 4. 应用配置并设置主题生效
      require("catppuccin").setup(opts)
      vim.cmd.colorscheme("catppuccin") -- 激活 Catppuccin 主题
    end,
  },
}
