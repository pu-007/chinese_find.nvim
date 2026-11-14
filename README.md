# chinese_find.nvim

Chinese/ASCII punctuation equivalence for Neovim's `f/F/t/T`, `;`, `,`, and operator repeats.

让半角和全角标点在字符查找中互相等价。`f,` 同时查找 `,` 和 `，`，`df；` 可以删除到半角或全角分号；`f\` 可以查找顿号 `、`。纯 Lua，只依赖 Neovim。

## 功能

- `f/F/t/T` 限定当前行，保留原生方向和停靠位置。
- 中英标点双向等价；输入 `,` 或 `，` 的效果相同。
- 支持普通、可视和操作符待决模式：`vf；`、`df；`、`cf；`、`yf；`。
- 支持计数、`;` 同向重复、`,` 反向重复、`.` 修改重复及宏。
- `f/F/t/T` 每次都读取新目标，不进入额外的遍历模式。
- 普通字符区分大小写、按字面匹配；不修改 `/` 搜索模式或缓冲区中的标点。
- 等价映射表可替换，不依赖 AstroNvim、Leap、Flash 或 vim-repeat。

当前回归环境：Neovim 0.12.6。仓库包含不加载用户配置的原生行为对照测试。

## 安装

### lazy.nvim

```lua
{
  "pu-007/chinese_find.nvim",
  main = "chinese_find",
  event = "VeryLazy",
  opts = {},
}
```

建议在插件加载前设置 `vim.g.maplocalleader = "\\"`，给反向重复键 `,` 留出独立按键。插件不会替你修改 Leader 或其他配置；已有 `\` 映射的用户应自行协调前缀。

不要同时启用其他接管 `f/F/t/T/;/,` 的插件。后加载的映射会覆盖先加载的映射。

### 原生 package / 手动安装

```sh
git clone https://github.com/pu-007/chinese_find.nvim \
  ~/.local/share/nvim/site/pack/plugins/start/chinese_find.nvim
```

在 `init.lua` 中初始化：

```lua
require("chinese_find").setup()
```

也可以只复制 `lua/chinese_find.lua` 到自己的配置目录，然后执行同一个 `setup()`。

### AstroNvim / AstroCore

在 `lua/plugins/chinese_find.lua` 中注册依赖及 AstroCore 映射，避免重复调用两套按键配置：

```lua
return {
  "AstroNvim/astrocore",
  dependencies = { "pu-007/chinese_find.nvim" },
  opts = function(_, opts)
    local find = require "chinese_find"
    find.setup { mappings = false }
    for _, mode in ipairs { "n", "x", "o" } do
      opts.mappings[mode] = opts.mappings[mode] or {}
      for _, key in ipairs { "f", "F", "t", "T", ";", "," } do
        opts.mappings[mode][key] = {
          function() return find.expr(key) end,
          expr = true,
          desc = "字符查找 " .. key .. "（中英标点等价）",
        }
      end
    end
  end,
}
```

AstroNvim 的 `maplocalleader` 在发行版初始化选项中设置。如果原先使用 `,`，应迁移到不与查找键重叠的前缀，并检查该前缀已有的分屏等按键。

## 使用

| 按键 | 行为 |
| --- | --- |
| `f,` / `f，` | 向右找到逗号，停在标点上 |
| `F,` | 向左找到逗号，停在标点上 |
| `t,` | 向右找逗号，停在标点前一个字符 |
| `T,` | 向左找逗号，停在标点后一个字符 |
| `f;` / `f；` | 查找半角或全角分号 |
| `f\` / `f、` | 查找反斜杠或顿号 |
| `2f,` | 查找第 2 个等价逗号 |
| `;` / `,` | 按最近一次查找的原方向 / 相反方向重复 |
| `2;` / `2,` | 带计数的同向 / 反向重复 |
| `df；` | 删除到下一个分号，包含标点 |
| `dt；` | 删除到下一个分号之前，保留标点 |
| `d2f；` / `2df；` | 删除到第 2 个等价分号 |
| `cf；` / `yf；` | 修改 / 复制到分号 |
| `vf；` | 可视选择到分号 |
| `df\` | 删除到下一个顿号或反斜杠 |
| `d;` / `d,` | 使用最近的字符查找作为删除范围 |
| `.` | 重复上次修改，可以连续执行 |
| `2.` | 以新计数 2 重复修改，而不是执行两次独立的 `.` |
| `Esc` | 取消正在等待目标字符的查找 |

例如，光标在 `甲；乙;丙；丁` 的 `甲` 上：

```text
df；  -> 乙;丙；丁
.     -> 丙；丁
.     -> 丁
```

删除后光标停在原位置也能立即 `.`。`,` 不改变下次 `;` 的原方向。`t/T` 第一次查找相邻标点可以停在原位，后续 `;` 继续查找其他目标；无目标或计数不足时不跨行，也不误删当前字符。

单独用于重复的命令键是半角 `;` 和 `,`；作为目标的字符可以输入全角。`f\` 中的反斜杠由 f 读取，不触发 `<LocalLeader>`。

## 配置

### 默认等价表

键与值里的所有字符组成同一个双向等价组：

```lua
{
  [","] = "，",
  [";"] = "；",
  [":"] = "：",
  ["!"] = "！",
  ["?"] = "？",
  ["("] = "（",
  [")"] = "）",
  ["."] = "。",
  ['"'] = "“”",
  ["'"] = "‘’",
  ["\\"] = "、",
}
```

Lua 字符串中的 `"\\"` 表示一个反斜杠。一个键应为单个字符，值可以包含多个别名；不同组不要重复包含同一个字符。

### 替换或扩展映射表

直接传给 `setup()` 的 `equivalents` 会替换整张表，未列出的字符按字面查找：

```lua
require("chinese_find").setup {
  equivalents = {
    [","] = "，",
    [";"] = "；",
    ["\\"] = "、",
  },
}
```

在默认表上扩展：

```lua
local find = require "chinese_find"
local equivalents = vim.deepcopy(find.defaults)
equivalents["["] = "【"
equivalents["]"] = "】"
find.setup { equivalents = equivalents }
```

使用 lazy.nvim 时也可通过自定义 `config` 调用上述 `setup()`，确保只初始化一次。`mappings = false` 只初始化等价关系，不注册默认按键，适合 AstroCore 或自行管理映射的配置。

### 自行注册映射

`expr(key)` 返回供表达式映射执行的命令；`key` 为 `f`、`F`、`t`、`T`、`;`、`,` 之一：

```lua
local find = require "chinese_find"
find.setup { mappings = false }
vim.keymap.set({ "n", "x", "o" }, "f", function()
  return find.expr "f"
end, { expr = true })
```

以上只演示一个键，完整接管需注册六个键。`_jump` 是重放命令使用的内部入口，不应由用户直接调用。

## 实现与范围

模块先在当前行选择等价目标，再交给原生 `f/F/t/T` 执行实际移动。表达式映射记录目标与计数，使 `.` 无需再次读取目标字符，也无需修改 vim-repeat 的 tick。

这是字符查找插件；不提供拼音查找、中文分词、输入法切换或 surround。等价表不会修改其他插件的包围符定义。命令绕过映射时（例如 `:normal! f,`）仍执行原生的字面查找。

## 开发与测试

```sh
nvim --headless -u NONE -i NONE -l tests/chinese_find.lua
```

测试为被测插件和原生 Neovim 分别启动独立进程，附加 UI 后输入相同的按键序列。中文标点先归一化，再对比缓冲区、光标、模式和寄存器。测试不依赖用户配置、AstroNvim、插件管理器或第三方测试框架。

覆盖 44 个场景、129 次断言：正反向和 till 查找、全角 `df；/dt；`、顿号、计数、连续点重复、宏、可视模式、跨行后重复、无目标及强制 motion 的空范围处理。

## 许可证

[MIT](LICENSE)
