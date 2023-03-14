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

function find_client_with_capabilitiy(group, cap)
  local all_clients = vim.lsp.get_active_clients()

  for _, client in ipairs(all_clients) do
    if client.config.capabilities[group] and client.config.capabilities[group][cap] then
      return client
    end
  end
end

function M.references()
  local refs = nil

  local client = find_client_with_capabilitiy('textDocument', 'references')
  local original_handler = client.handlers['textDocument/references']

  -- This is a rather complex alternative to `on_list` option of `vim.lsp.buf.references()`
  -- Becuase on_list isn't called when there are no references found (for some idiotic reason).
  client.handlers['textDocument/references'] = function(_, result, ctx, config)
    if not result or vim.tbl_isempty(result) then
      refs = {}
    else
      config = config or {}
      refs = util.locations_to_items(result, client.offset_encoding)
    end
  end

  vim.lsp.buf.references()
  vim.wait(3000, function() return refs ~= nil end, 10)

  client.handlers['textDocument/references'] = original_handler
  return refs
end

return M
