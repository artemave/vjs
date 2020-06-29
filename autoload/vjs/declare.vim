fun! vjs#declare#CreateDeclaration() abort
  let code = join(getline(1, '$'), "\n")
  let context = {'reference': expand('<cword>')}

  let current_line = getline('.')
  let cursor_column = getcurpos()[2]
  let [match, match_start, match_end] = matchstrpos(current_line, context.reference .' *(')

  if match != '' && match_start <= cursor_column && match_end >= cursor_column
    let context.reference_type = 'function'
  else
    let context.reference_type = 'variable'
  endif

  let message = {'code': code, 'start_line': line('.'), 'action': 'create_declaration', 'context': context}

  call vjs#ipc#SendMessage(message, funcref('s:HandleCreateDeclarationResponse'))
endf

fun! s:HandleCreateDeclarationResponse(message) abort
  let reference = a:message.context.reference
  let reference_type = a:message.context.reference_type

  if !has_key(a:message, 'declaration')
    echohl Warn | echom reference .' is either already declared, or can not be declared in this context' | echohl None
    return
  endif

  let declaration_line = a:message.declaration.line - 1
  let indent = repeat(' ', a:message.declaration.column)
  let new_lines = []

  if reference_type == 'variable'
    call add(new_lines, indent .'const '. reference . ' = ')
  else
    call add(new_lines, indent .'function '. reference . '() {')
    call add(new_lines, indent .'}')
  endif

  if getline(declaration_line + 1) != ''
    call add(new_lines, '')
  endif

  call append(declaration_line, new_lines)
  execute ':'.(declaration_line + 1)

  if reference_type == 'variable'
    startinsert!
  else
    normal f(l
    startinsert
  endif
endf
