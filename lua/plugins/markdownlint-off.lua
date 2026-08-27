-- 只关掉 LazyVim lang.markdown extra 的「风格规则检查」markdownlint-cli2(MD001~MD###),
-- 保留 marksman(Markdown LSP) 的诊断(断链/重复标题等可接受)。
--
-- 若想连 marksman 一起关掉,取消下面 nvim-lspconfig 块的注释即可。
return {
  -- 关掉 nvim-lint 对 markdown 的 markdownlint-cli2 检查。
  -- LazyVim 直接 lint.linters_by_ft = opts.linters_by_ft;
  -- markdown = {} 会替换(而非合并)掉 extra 写入的 {"markdownlint-cli2"} => 不再检查。
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters_by_ft = {
        markdown = {},
      },
    },
  },

  -- 可选: 连 marksman(Markdown LSP) 也一起关
  -- {
  --   "neovim/nvim-lspconfig",
  --   opts = {
  --     servers = {
  --       marksman = false,
  --     },
  --   },
  -- },
}
