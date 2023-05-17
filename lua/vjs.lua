local ts = vim.treesitter
local query = require "vim.treesitter.query"
local utils = require "nvim-treesitter.utils"
local parsers = require "nvim-treesitter.parsers"

local M = {}

function M.find_statement_start()
  local node = ts.get_node()
  local buf = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  -- vim.api.nvim_command(string.format('Log("%s")', node))

  -- find the first parent node with type that math *._statement or "declaration"
  while node and not (string.match(node:type(), ".*_statement") or string.match(node:type(), ".*_declaration")) do
    -- local start_row, start_col, _ = node:start()
    -- vim.api.nvim_command(string.format('Log("%s, %d, %d")', node:type(), start_row, start_col))
    node = node:parent()
  end

  if not node then
    return { line = 1, column = 0 }
  end

  local start_row, start_col, _ = node:start()
  return {
    line = start_row + 1,
    column = start_col,
  }
end

function M.to_template_string()
  local node_at_cursor = ts.get_node()

  if node_at_cursor:type() ~= 'string_fragment' then
    return
  end

  local node_at_cursor_text = ts.get_node_text(node_at_cursor, 0)
  local node_with_quotes = node_at_cursor:parent()
  local node_with_quotes_text = ts.get_node_text(node_with_quotes, 0)

  if string.match(node_with_quotes_text, "^`") or not string.match(node_at_cursor_text, "%${") then
    return
  end

  -- replace node_with_quotes with node_at_cursor wrapped in ``
  local start_row, start_col, _ = node_with_quotes:start()
  local end_row, end_col, _ = node_with_quotes:end_()
  local buf = vim.api.nvim_buf_get_lines(0, 0, -1, false)

  buf[start_row + 1] = string.sub(buf[start_row + 1], 1, start_col) .. "`" .. string.sub(buf[start_row + 1], start_col + 2)
  buf[end_row + 1] = string.sub(buf[end_row + 1], 1, end_col - 1) .. "`" .. string.sub(buf[end_row + 1], end_col + 1)

  vim.api.nvim_buf_set_lines(0, 0, -1, false, buf)
end

return M
