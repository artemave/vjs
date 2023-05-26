let s:v_reg = ''
let s:s_reg = ''

fun! vjs#extract#ExtractFunctionOrMethod()
  let s:v_reg = @v
  let s:s_reg = @s

  let @v = input('Function name: ')
  if empty(@v)
    return
  endif

  let selection_start_line = getpos("'<")[1]
  let selection_end_line = getpos("'>")[1]

  let function_arguments = luaeval('require"vjs".find_variables_used_within_selection_but_defined_outside('.selection_start_line.', '.selection_end_line.')')
  let return_values = luaeval('require"vjs".find_variables_defined_within_selection_but_used_outside('.selection_start_line.', '.selection_end_line.')')

  " TODO: why gv needed?
  normal gv
  undojoin | normal "sx

  if match(@v, '^\<this\>\.') > -1 || match(@s, '\<this\>') > -1
    let @v = substitute(@v, '^\<this\>\.', '', '')
    let [type, line, column] = luaeval('require"vjs".extracted_type_and_loc({ bound = true })')
  else
    let [type, line, column] = luaeval('require"vjs".extracted_type_and_loc({ bound = false })')
  endif

  let response = {'function_arguments': function_arguments, 'return_values': return_values, 'line': line, 'column': column, 'type': type}

  call s:HandleExtractFunctionResponse(response)
endf

fun! vjs#extract#ExtractLocalFunction()
  let s:v_reg = @v
  let s:s_reg = @s

  let @v = input('Function name: ')
  if empty(@v)
    return
  endif

  let selection_start_line = getpos("'<")[1]
  let selection_end_line = getpos("'>")[1]

  let function_arguments = []
  let return_values = luaeval('require"vjs".find_variables_defined_within_selection_but_used_outside('.selection_start_line.', '.selection_end_line.')')

  let type = 'function'
  let loc = {'line': selection_start_line - 1, 'column': line('.')->indent()}
  let response = {'function_arguments': function_arguments, 'return_values': return_values, 'line': loc.line, 'column': loc.column, 'type': type}

  normal gv
  undojoi | normal "sx

  call s:HandleExtractFunctionResponse(response)
endf

fun! vjs#extract#ExtractVariable()
  let [selection_start_line, selection_start_column] = getpos("'<")[1:2]
  let [selection_end_line, selection_end_column] = getpos("'>")[1:2]

  let text_before_selection_start = getline(selection_start_line)[0:selection_start_column - 2]
  let property_name_match = matchlist(text_before_selection_start, '\(\w\+\) *: *$')
  let property_name = ''
  if len(property_name_match) > 1
    let property_name = property_name_match[1]
  endif

  let s:v_reg = @v
  let s:s_reg = @s

  let @v = input('Variable name: ', property_name)
  if empty(@v)
    return
  endif

  let loc = luaeval('require"vjs".find_statement_start()')

  let indent = repeat(' ', loc.column)
  let current_indent_base = indent(line('.'))

  normal gv
  let last_selected_line_includes_line_break = selection_end_column > 999999 || len(getline(selection_end_line)) <= selection_end_column
  if last_selected_line_includes_line_break
    normal $h
  endif
  normal "sx

  if @v == property_name
    let new_line = substitute(getline(selection_start_line), property_name.' *: *', property_name, '')
    call setline(selection_start_line, new_line)
  else
    if last_selected_line_includes_line_break
      undojoin | normal "vp
    else
      undojoin | normal "vP
    endif
  endif

  let new_lines = split(indent ."const ". @v ." = ". @s, "\n")
  call map(new_lines, {idx, line -> idx > 0 ? substitute(line, "^".repeat(' ', current_indent_base - loc.column), '', '') : line})
  call add(new_lines, '')

  undojoin | call append(loc.line, new_lines)

  let @v = s:v_reg
  let @s = s:s_reg
endf

fun! s:HandleExtractFunctionResponse(message) abort
  let is_async = match(@s, '\<await ')

  let extracted_lines = s:ExtractedFunctionLines(a:message, is_async)
  let @v = s:InvokationLine(a:message, is_async)

  if match(@s, '\n$') > -1
    normal "vP
  else
    normal "vp
  endif
  undojoin | normal ==

  undojoin | call append(a:message.line, extracted_lines)
  let save_cursor = getcurpos()
  call setpos('.', [0, a:message.line, 0, 0])
  " TODO: replace all `normal` with `normal!`
  undojoin | silent execute 'normal!' '='.(len(extracted_lines) + 1).'j'
  call setpos('.', save_cursor)

  let @v = s:v_reg
  let @s = s:s_reg
endf

fun s:ExtractedFunctionLines(message, is_async)
  let new_lines = split(@s, "\n")
  let first_new_line = s:FirstNewLine(a:message, a:is_async)

  call insert(new_lines, first_new_line)

  let return_value_line = s:ReturnValueLine(a:message)
  if len(return_value_line)
    call add(new_lines, return_value_line)
  endif

  let closing_bracket = '}'
  if a:message.type == 'object_method'
    let closing_bracket = closing_bracket. ','
  endif
  call extend(new_lines, [closing_bracket, ''])

  return new_lines
endf

fun s:FirstNewLine(message, is_async)
  let args = join(a:message.function_arguments, ', ')

  if a:message.type == 'arrow_function'
    let first_new_line = 'const '. @v .' = '
    if a:is_async > -1
      let first_new_line = 'async '. first_new_line
    endif
    let first_new_line = first_new_line . '('. args .') => {'
  else
    let first_new_line = a:message.type == 'function' ? 'function ' : ''

    let first_new_line = first_new_line. @v .'('. args .') {'

    if a:is_async > -1
      let first_new_line = 'async '. first_new_line
    endif
  endif

  return first_new_line
endf

fun s:ReturnValueLine(message)
  if len(a:message.return_values) == 1
    return repeat(' ', &shiftwidth) .'return '.a:message.return_values[0].name
  elseif len(a:message.return_values) > 1
    return repeat(' ', &shiftwidth) .'return {'. s:VariableNames(a:message) .'}'
  end
  return ''
endf

fun s:InvokationLine(message, is_async)
  let invokation_line = @v ."(". join(a:message.function_arguments, ', ') .")\n"

  if a:message.type == 'object_method' || a:message.type == 'method'
    let invokation_line = 'this.'. invokation_line
  endif

  if a:is_async > -1
    let invokation_line = 'await '. invokation_line
  endif

  if len(a:message.return_values) == 1
    let invokation_line = 'const '. a:message.return_values[0].name .' = '. invokation_line
  elseif len(a:message.return_values) > 1
    let invokation_line = 'const {'. s:VariableNames(a:message) .'} = '. invokation_line
  endif

  return invokation_line
endf

fun s:VariableNames(message)
  return join(map(copy(a:message.return_values), {_, v -> v.name}), ', ')
endf

fun vjs#extract#ExtractDeclarationIntoFile()
  let code = join(getline(1,'$'), "\n")
  let message = {'code': code, 'start_line': line('.'), 'action': 'extract_declaration'}

  call vjs#ipc#SendMessage(message, funcref('s:HandleExtractDeclarationResponse'))
endf

fun s:HandleExtractDeclarationResponse(message)
  if !has_key(a:message, 'declaration')
    echom 'No declaration found under cursor'
    return
  endif

  let name = a:message.declaration.name
  let new_file_path = input('Extract '. name .' into ', s:expand('%:h') .'/'. name .'.'. s:expand('%:e'), 'file')

  if new_file_path == ''
    return
  endif

  let start_line = a:message.declaration.start_line
  let end_line = a:message.declaration.end_line

  " if declaration is surrounded by empty lines, remove one of them
  if start_line > 1 && getline(start_line - 1) == '' && end_line < line('$') && getline(end_line + 1) == ''
    let end_line = end_line + 1
  endif

  let s:v_reg = @v
  execute start_line .','. end_line .'d' 'v'

  let indent_to_remove = indent(start_line)
  let new_file_lines = split(@v, "\n", 1)
  call map(new_file_lines, {_, line -> substitute(line, '^'.repeat(' ', indent_to_remove), '', '') })

  " drop empty lines at the end
  while new_file_lines[-1] == ''
    let new_file_lines = new_file_lines[0:-2]
  endwhile

  let new_file_lines[0] = s:ExportStatement(new_file_lines[0])
  call s:writefile(new_file_lines, new_file_path)

  let importing_module_full_path_parts = split(s:expand('%:p'), '/')
  let imported_module_full_path_parts = split(fnamemodify(new_file_path, ':p:r'), '/')
  let import_path_parts = vjs#imports#calculateImportPathParts(importing_module_full_path_parts, imported_module_full_path_parts)

  let import_line = s:LastImportLine()
  undojoin | call append(import_line, s:ImportStatement(name, join(import_path_parts, '/')))

  if !exists('g:vjs_test_env')
    execute 'split' new_file_path
  endif

  let @v = s:v_reg
endf

fun s:LastImportLine() abort
  let line = 0
  if match(getline(1), '^#!') > -1
    let line = 2
  endif
  return line
endf

fun s:ExportStatement(declaration_line)
  if search('^\s*import ') > 0
    return 'export default '. a:declaration_line
  else
    return 'module.exports = '. substitute(a:declaration_line, ' *\(var\|let\|const\) [^=]*= *', '', '')
  endif
endf

fun s:ImportStatement(name, path)
  if search('^\s*import ') > 0
    return 'import '. a:name ." from '". a:path ."'"
  else
    return 'const '. a:name ." = require('". a:path ."')"
  endif
endf

fun s:writefile(lines, path)
  if exists('g:vjs_test_env')
    let g:test_extracted_file_name = a:path
    let g:test_extracted_file_lines = a:lines
  else
    return writefile(a:lines, a:path)
  endif
endf

fun s:expand(expr)
  if exists('g:vjs_test_env')
    return fnamemodify(g:test_initial_file_name, a:expr[1:-1])
  else
    return expand(a:expr)
  endif
endf
