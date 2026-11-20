return {
  "folke/snacks.nvim",
  opts = {
    styles = {
      terminal = {
        keys = {
          -- 关掉 snacks 自带的“双击 Esc 退出终端模式”：
          -- 它只看按键间隔(200ms)，不区分终端前台跑的是什么程序，
          -- 会把 codex / claude code / less 这类把 Esc 当“中断”的 TUI 的按键抢走。
          -- 改用 lua/config/keymaps.lua 里那个“仅 shell 提示符下生效”的全局
          -- t 模式映射，这样 snacks 终端和 :terminal 的行为完全一致。
          term_normal = false,
        },
      },
    },
  },
}
