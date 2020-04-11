fun! vjs#extract#ExtractFunction()
  " TODO: restore @v
  let @v = input('Function name: ')
  if empty(@v)
    return
  endif

  let code = join(getline(1,'$'), "\n")
  let context = {'action': 'extract_function'}
  let message = {'code': code, 'current_line': line('.'), 'query': 'findStatementStart', 'context': context}

  call vjs#ipc#SendMessage(json_encode(message))
endf

fun! vjs#extract#ExtractVariable()
  let [selection_start_line, selection_start_column] = getpos("'<")[1:2]
  let text_before_selection_start = getline(selection_start_line)[0:selection_start_column - 2]
  let property_name_match = matchlist(text_before_selection_start, '\(\w\+\) *: *$')
  let property_name = ''
  if len(property_name_match) > 1
    let property_name = property_name_match[1]
  endif

  let @v = input('Variable name: ', property_name)
  if empty(@v)
    return
  endif

  " send buffer content and line('.') to js
  let code = join(getline(1,'$'), "\n")
  let context = {'property_name': property_name, 'action': 'extract_variable'}
  let message = {'code': code, 'current_line': line('.'), 'query': 'findStatementStart', 'context': context}

  call vjs#ipc#SendMessage(json_encode(message))
endf

fun! vjs#extract#RefactoringResponseHandler(channel, response, ...) abort
  let message = json_decode(a:response)

  if message.context.action == 'extract_variable'
    let new_lines = s:HandleExtractVariableResponse(message)
  elseif message.context.action == 'extract_function'
    let new_lines = s:HandleExtractFunctionResponse(message)
  else
    throw 'Unknown action '. message.context.action
  endif

  undojoin | call append(message.line - 1, new_lines)
endf

fun! s:HandleExtractVariableResponse(message) abort
  let indent = repeat(' ', a:message.column)
  let current_indent_base = indent(line('.'))
  let [selection_end_line, selection_end_column] = getpos("'>")[1:2]
  let last_selected_line_includes_line_break = selection_end_column > 999999 || len(getline(selection_end_line)) == selection_end_column

  let property_name = a:message.context.property_name

  let selection_start_line = getpos("'<")[1]

  normal gv
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

  return new_lines
endf

fun! s:HandleExtractFunctionResponse(message) abort
  let indent = repeat(' ', a:message.column)

  normal gv
  normal "sx

  let is_async = match(@s, '\<await ')

  let first_new_line = 'function '. @v .'() {'
  if is_async > -1
    let first_new_line = 'async '. first_new_line
  endif

  let @v = @v ."()\n"
  if is_async > -1
    let @v = 'await '. @v
  endif

  if match(@s, '\n$') > -1
    undojoin | normal "vP
  else
    undojoin | normal "vp
  endif
  undojoin | normal ==

  let new_lines = split(@s, "\n")
  call map(new_lines, {_, line -> repeat(' ', &shiftwidth) . line})
  call insert(new_lines, indent . first_new_line)
  call extend(new_lines, [indent .'}', ''])

  return new_lines
endf

