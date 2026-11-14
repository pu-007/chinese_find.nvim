-- 独立的单行字符查找模块；只依赖 Neovim，可直接复制到其他配置的 lua/。
local M = {}

-- 键与值内的每个字符双向等价。setup({ equivalents = {...} }) 可替换整张表。
M.defaults = {
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
local equivalents = {}
local last_search
local keys = { "f", "F", "t", "T", ";", "," }

-- 表达式映射把本次输入编码到命令中；Neovim 的 . 会重放命令，而不会再次读键。
function M.expr(key)
  local char, backward, till
  local repeated = key == ";" or key == ","
  if not repeated then
    local ok, input = pcall(vim.fn.getcharstr)
    if not ok or input == "\27" or vim.fn.strchars(input) ~= 1 then return "<Esc>" end
    char, backward, till = input, key == "F" or key == "T", key == "t" or key == "T"
    last_search = { char = char, backward = backward, till = till }
  else
    backward = key == "," -- . 重复 d;/d, 时同样使用最近一次的查找。
  end
  return ("<Cmd>lua require('chinese_find')._jump(%s,%s,%s,%d,%s)<CR>"):format(
    vim.inspect(char), tostring(backward), tostring(till), vim.v.count1, tostring(repeated)
  )
end

function M._jump(char, backward, till, count, repeated)
  -- 显式的 2. 会覆盖上次计数；没有新计数时保留表达式映射记录的值。
  if vim.v.count > 0 then count = vim.v.count end
  if repeated then
    if not last_search then return end
    char, till = last_search.char, last_search.till
    backward = last_search.backward ~= backward
  end
  local line = vim.api.nvim_get_current_line()
  local chars = vim.fn.split(line, "\\zs")
  local current = vim.fn.charidx(line, vim.api.nvim_win_get_cursor(0)[2]) + 1
  local direction = backward and -1 or 1
  local skip_adjacent = repeated and till and count == 1 and not vim.o.cpoptions:find(";", 1, true)
  local matches, counts = equivalents[char], {}
  local target, native_count, target_index
  for i = current + direction, backward and 1 or #chars, direction do
    local candidate = chars[i]
    if candidate == char or (matches and matches[candidate]) then
      counts[candidate] = (counts[candidate] or 0) + 1
      if not (skip_adjacent and i == current + direction) then
        count = count - 1
        if count == 0 then
          target, native_count, target_index = candidate, counts[candidate], i
          break
        end
      end
    end
  end
  local mode = vim.fn.mode(1)
  if not target or (mode == "nov" and not backward and till and target_index == current + 1) then
    -- 同步取消待决操作符；:normal 内的 Esc 不能清除外层强制 motion 状态。
    if mode:sub(1, 2) == "no" then vim.api.nvim_feedkeys("\27", "nix", false) end
    return
  end
  local motion = till and (backward and "T" or "t") or (backward and "F" or "f")
  -- 默认前向 motion 包含终点；显式 dvf 则排除终点。
  if not backward and mode == "no" then vim.cmd.normal { args = { "v" }, bang = true } end
  -- 最终交给原生 f/F/t/T 执行，保留多字节偏移、操作符与可视选择语义。
  vim.cmd.normal { args = { native_count .. motion .. target }, bang = true }
  if not backward and mode == "nov" then vim.cmd.normal { args = { "h" }, bang = true } end
end

function M.setup(opts)
  opts = opts or {}
  equivalents = {}
  for char, aliases in pairs(opts.equivalents or M.defaults) do
    local group = {}
    for _, member in ipairs(vim.fn.split(char .. aliases, "\\zs")) do group[member] = true end
    for member in pairs(group) do equivalents[member] = group end
  end
  if opts.mappings == false then return end
  for _, key in ipairs(keys) do
    vim.keymap.set({ "n", "x", "o" }, key, function() return M.expr(key) end, {
      expr = true,
      desc = "字符查找 " .. key .. "（中英标点等价）",
    })
  end
end

return M
