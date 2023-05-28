local ts = vim.treesitter
local ts_locals = require("nvim-treesitter.locals")

local function dump(o)
  if type(o) == 'table' then
    local s = '{ '
    for k,v in pairs(o) do
        if type(k) ~= 'number' then k = '"'..k..'"' end
        s = s .. '['..k..'] = ' .. dump(v) .. ','
    end
    return s .. '} '
  else
    return tostring(o)
  end
end

local M = {}

local function find_start(condition_fn)
  local node = ts.get_node()

  while node and condition_fn(node) do
    node = node:parent()
  end

  if not node then
    return { line = 1, column = 0 }
  end

  local start_row, start_col, _ = node:start()

  return {
    line = start_row,
    column = start_col,
  }
end

local function find_end(condition_fn)
  local node = ts.get_node()

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

-- TODO: this is a bit silly: global scope start is always line 1
function M.find_global_scope_start()
  return find_start(function(node)
    return not string.match(node:type(), ".*_file")
  end)
end

function M.find_closest_global_scope(n)
  local node = n or ts.get_node()

  return find_start(function(node)
    return node:parent() and node:parent():type() ~= 'program'
  end)
end

function M.method_definition_start()
  return find_start(function(node)
    local is_method = string.match(node:type(), "method_definition")
    local is_function_property = string.match(node:type(), 'function') and string.match(node:parent():type(), 'pair')

    -- TODO: invert this
    return not is_method and not is_function_property
  end)
end

function M.method_definition_end()
  return find_end(function(node)
    return not string.match(node:type(), "method_definition")
  end)
end

function M.function_body_start()
  local function_declaration = closest_of_type('function_declaration')
  local start_row, start_col, _ = function_declaration:field('body')[1]:start()

  return {
    line = start_row + 1,
    column = start_col,
  }
end

function closest_with_field(name, n)
  local node = n or ts.get_node()

  while node do
    if #node:field(name) > 0 then
      return node
    end
    node = node:parent()
  end
end

function closest_of_type(types, n)
  local node = n or ts.get_node()

  if type(types) ~= 'table' then
    types = { types }
  end

  while node and node:parent() do
    for _, t in ipairs(types) do
      if node:type() == t then
        return node
      end
    end
    node = node:parent()
  end
end

function M.extracted_type_and_loc(opts, n)
  local node = n or ts.get_node()

  if not opts.bound then
    local loc = M.find_closest_global_scope(n)
    return { 'function', loc.line, loc.column }
  end
  local container_node = closest_with_field('body', node)

  if container_node then
    local line, column  = container_node:start()

    if container_node:type() == 'method_definition' then
      if container_node:parent():type() == 'class_body' then
        return { 'method', line, column }
      else
        return { 'object_method', line, column }
      end
    elseif container_node:type() == 'arrow_function' then
      return M.extracted_type_and_loc(opts, container_node:parent())
    elseif container_node:type() == 'function_declaration' or container_node:type() == 'function' then
      if container_node:parent():type() == 'pair' then
        return { 'object_method', line, column }
      else
        return { 'arrow_function', line + 1, column }
      end
    else
      local text = ts.get_node_text(container_node, 0)
      error(string.format("Unhandled node of type %s:\n%s", container_node:type(), text))
    end
  end

  local loc = M.find_closest_global_scope(n)
  return { 'function', loc.line, loc.column }
end

function M.find_variables_defined_within_selection_but_used_outside(start_line, end_line)
  local references = ts_locals.get_references(0)
  local res = {}

  vim.tbl_map(function(reference)
    local def = ts_locals.find_definition(reference, 0)
    local def_start, _, _ = def:start() + 1
    local ref_end, _, _ = reference:end_() + 1
    local def_name = ts.get_node_text(def, 0)

    if def_start >= start_line and def_start <= end_line and ref_end > end_line then
      -- check if table contains { name = def_name }
      local found = false
      for _, def in ipairs(res) do
        if def.name == def_name then
          found = true
          break
        end
      end

      if not found then
        table.insert(res, { name = def_name })
      end
    end
  end, references)

  return res
end

function M.find_variables_used_within_selection_but_defined_outside(start_line, end_line)
  local references = ts_locals.get_references(0)
  local res = {}

  vim.tbl_map(function(reference)
    local def = ts_locals.find_definition(reference, 0)
    local def_start, _, _ = def:start() + 1
    local ref_start, _, _ = reference:start() + 1
    local def_name = ts.get_node_text(def, 0)

    if reference:type() ~= 'identifier' then
      return
    end

    if def_start < start_line and ref_start >= start_line and ref_start <= end_line then
      local lexical_scope = closest_of_type('lexical_declaration', def:parent())
      if lexical_scope and lexical_scope:parent() then
        local found = false
        for _, name in ipairs(res) do
          if name == def_name then
            found = true
            break
          end
        end

        if not found then
          table.insert(res, def_name)
        end
      end
    end
  end, references)

  return res
end

function M.closest_declaration()
  local node = closest_of_type({ 'function_declaration', 'class_declaration' })
  if node then
    local name = ts.get_node_text(node:field('name')[1], 0)
    return {
      name = name,
      start_line = node:start() + 1,
      end_line = node:end_() + 1
    }
  end
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
