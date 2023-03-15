local ts_utils = require "nvim-treesitter.ts_utils"
local query = require "vim.treesitter.query"
local utils = require "nvim-treesitter.utils"
local parsers = require "nvim-treesitter.parsers"
local util = require('vim.lsp.util')

local M = {}

function M.find_statement_start()
  local node = ts_utils.get_node_at_cursor()
  local buf = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  -- vim.api.nvim_command(string.format('Log("%s")', node))

  -- find the first parent node with type that match *._statement or "declaration"
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

return M
