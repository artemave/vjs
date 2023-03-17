local ts_utils = require "nvim-treesitter.ts_utils"
local query = require "vim.treesitter.query"
local utils = require "nvim-treesitter.utils"
local parsers = require "nvim-treesitter.parsers"
local util = require('vim.lsp.util')

local M = {}

function M.find_statement_start()
  local node = ts_utils.get_node_at_cursor()

  -- find the first parent node with type that match *._statement or "declaration"
  while node and not (string.match(node:type(), ".*_statement") or string.match(node:type(), ".*_declaration")) do
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

function M.find_global_scope_start()
  local node = ts_utils.get_node_at_cursor()

  -- find parent node in global scope
  while node and not (string.match(node:type(), ".*_file")) do
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
