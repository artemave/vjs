let s:v_reg = ''
let s:s_reg = ''

fun! vjs#extract#ExtractFunctionOrMethod(...)
  if a:0 > 0
    let action = 'extract_local_function'
  else
    let action = 'extract_function_or_method'
  endif

  let s:v_reg = @v
  let s:s_reg = @s

  let @v = input('Function name: ')
  if empty(@v)
    return
  endif

  let selection_start_line = getpos("'<")[1]
  let selection_end_line = getpos("'>")[1]

  let code = join(getline(1,'$'), "\n")
  let message = {'code': code, 'start_line': selection_start_line, 'end_line': selection_end_line, 'action': action}

  call vjs#ipc#SendMessage(message)
endf

fun! vjs#extract#ExtractVariable()
  let [selection_start_line, selection_start_column] = getpos("'<")[1:2]
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

  let code = join(getline(1,'$'), "\n")
  let context = {'property_name': property_name}
  let message = {'code': code, 'start_line': selection_start_line, 'action': 'extract_variable', 'context': context}

  call vjs#ipc#SendMessage(message)
endf

fun! vjs#extract#RefactoringResponseHandler(channel, response, ...) abort
  let message = json_decode(a:response)

  try
    if has_key(message, 'error')
      throw message.error
    endif

    if message.context.action == 'extract_variable'
      let new_lines = s:HandleExtractVariableResponse(message)
    elseif message.context.action == 'extract_local_function' || message.context.action == 'extract_function_or_method'
      let new_lines = s:HandleExtractFunctionResponse(message)
    else
      throw 'Unknown action '. message.context.action
    endif

    undojoin | call append(message.line - 1, new_lines)
  finally
    let @v = s:v_reg
    let @s = s:s_reg
  endtry
endf

fun! s:HandleExtractVariableResponse(message) abort
  let indent = repeat(' ', a:message.column)
  let current_indent_base = indent(line('.'))
  let [selection_end_line, selection_end_column] = getpos("'>")[1:2]
  let last_selected_line_includes_line_break = selection_end_column > 999999 || len(getline(selection_end_line)) <= selection_end_column

  let property_name = a:message.context.property_name

  let selection_start_line = getpos("'<")[1]

  normal gv
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
  call map(new_lines, {idx, line -> idx > 0 ? substitute(line, "^".repeat(' ', current_indent_base - a:message.column), '', '') : line})
  call add(new_lines, '')

  return new_lines
endf

fun! s:HandleExtractFunctionResponse(message) abort
  normal gv
  normal "sx

  let is_async = match(@s, '\<await ')

  let extracted_lines = s:ExtractedFunctionLines(a:message, is_async)
  let @v = s:InvokationLine(a:message, is_async)

  if match(@s, '\n$') > -1
    undojoin | normal "vP
  else
    undojoin | normal "vp
  endif
  undojoin | normal ==

  return extracted_lines
endf

fun s:ExtractedFunctionLines(message, is_async)
  let indent = repeat(' ', a:message.column)
  let new_lines = split(@s, "\n")
  let copy_indent = len(new_lines[0]) - len(substitute(new_lines[0], "^ *", '', ''))

  let first_new_line = s:FirstNewLine(a:message, a:is_async)

  " remove indent from copied text
  call map(new_lines, {_, line -> substitute(line, '^'.repeat(' ', copy_indent), '', '') })

  call map(new_lines, {_, line -> len(line) > 0 ? indent . repeat(' ', &shiftwidth) . line : line})
  call insert(new_lines, indent . first_new_line)

  let return_value_line = s:ReturnValueLine(a:message, indent)
  if len(return_value_line)
    call add(new_lines, return_value_line)
  endif

  let closing_bracket = '}'
  if a:message.type == 'objectMethod'
    let closing_bracket = closing_bracket. ','
  endif
  call extend(new_lines, [indent . closing_bracket, ''])

  return new_lines
endf

fun s:FirstNewLine(message, is_async)
  let declaration = a:message.type == 'function' || a:message.type == 'unboundFunction' ? 'function ' : ''

  let first_new_line = declaration. @v .'('. join(a:message.function_arguments, ', ') .') {'
  if a:is_async > -1
    let first_new_line = 'async '. first_new_line
  endif

  return first_new_line
endf

fun s:ReturnValueLine(message, indent)
  if len(a:message.return_values) == 1
    return a:indent . repeat(' ', &shiftwidth) .'return '.a:message.return_values[0].name
  elseif len(a:message.return_values) > 1
    return a:indent . repeat(' ', &shiftwidth) .'return {'. s:VariableNames(a:message) .'}'
  end
  return ''
endf

fun s:InvokationLine(message, is_async)
  if a:message.type == 'unboundFunction'
    let invokation_line = @v .'.call('. join(insert(a:message.function_arguments, 'this'), ', ') .")\n"
  else
    let invokation_line = @v ."(". join(a:message.function_arguments, ', ') .")\n"
  endif

  if a:message.type == 'objectMethod' || a:message.type == 'classMethod'
    let invokation_line = 'this.'. invokation_line
  endif

  if a:is_async > -1
    let invokation_line = 'await '. invokation_line
  endif

  if len(a:message.return_values) == 1
    let invokation_line = a:message.return_values[0].kind .' '. a:message.return_values[0].name .' = '. invokation_line
  elseif len(a:message.return_values) > 1
    let kinds = map(copy(a:message.return_values), {_, v -> v.kind})
    let non_const_kinds = filter(kinds, 'v:val == "const"')

    let kind = ''
    if len(non_const_kinds) == 0
      let kind = 'const'
    else
      let kind = 'let'
    endif

    let invokation_line = kind .' {'. s:VariableNames(a:message) .'} = '. invokation_line
  endif

  return invokation_line
endf

fun s:VariableNames(message)
  return join(map(copy(a:message.return_values), {_, v -> v.name}), ', ')
endf
