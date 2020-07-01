fun! vjs#declare#CreateDeclaration() abort
  let code = join(getline(1, '$'), "\n")
  let context = {'reference': expand('<cword>')}

  let current_line = getline('.')
  let cursor_column = getcurpos()[2]
  let function_name = substitute(context.reference, '^.', '\l&', '')
  " this is to make sure matchstrpos is case sensitive
  let original_ignorecase = &ignorecase
  let &ignorecase = 0
  let [function_match, f_match_start, f_match_end] = matchstrpos(current_line, function_name .' *(')
  let &ignorecase = original_ignorecase

  if function_match != '' && f_match_start <= cursor_column && f_match_end >= cursor_column
    let context.reference_type = 'function'
  elseif context.reference =~ '^[A-Z]'
    " let [class_match, c_match_start, c_match_end] = matchstrpos(current_line, context.reference .' *(')
    let context.reference_type = 'class'
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
  elseif reference_type == 'function'
    call add(new_lines, indent .'function '. reference . '() {')
    call add(new_lines, indent .'}')
  else
    call add(new_lines, indent .'class '. reference . ' {')
    call add(new_lines, indent .'}')
  endif

  if getline(declaration_line + 1) != ''
    call add(new_lines, '')
  endif

  call append(declaration_line, new_lines)
  execute ':'.(declaration_line + 1)

  if reference_type == 'variable'
    startinsert!
  elseif reference_type == 'function'
    normal f(l
    startinsert
  endif
endf
