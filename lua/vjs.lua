local ts_utils = require "nvim-treesitter.ts_utils"
local query = require "vim.treesitter.query"
local utils = require "nvim-treesitter.utils"
local parsers = require "nvim-treesitter.parsers"
local util = require('vim.lsp.util')

local M = {}

local function find_start(condition_fn)
  local node = ts_utils.get_node_at_cursor()

  while node and condition_fn(node) do
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

local function find_end(condition_fn)
  local node = ts_utils.get_node_at_cursor()

  while node and condition_fn(node) do
    node = node:parent()
  end

  if not node then
    return { line = vim.fn.line('$'), column = 0 }
  end

  local end_row, end_col, _ = node:end_()

  return {
    line = end_row + 1,
    column = end_col - 1,
  }
end

function M.find_statement_start()
  return find_start(function(node)
    return not (
      string.match(node:type(), ".*_statement") or string.match(node:type(), ".*_declaration")
    )
  end)
end

function M.find_global_scope_start()
  return find_start(function(node)
    return not string.match(node:type(), ".*_file")
  end)
end

function M.method_definition_start()
  return find_start(function(node)
    return not string.match(node:type(), "method_definition")
  end)
end

function M.method_definition_end()
  return find_end(function(node)
    return not string.match(node:type(), "method_definition")
  end)
end

function closest_parent_of_type(type)
  local node = ts_utils.get_node_at_cursor()

  while node and node:parent() do
    node = node:parent()

    if node:type() == type then
      return node
    end
  end
end

function M.this_container_type()
  local container_node = closest_parent_of_type('method_definition')

  if container_node:parent():type() == 'class_body' then
    return 'classMethod'
  else
    return 'objectMethod'
  end
end

return M
