fun! vjs#declare#CreateDeclaration() abort
  let code = join(getline(1,'$'), "\n")
  let context = {'reference': expand('<cword>')}
  let message = {'code': code, 'start_line': line('.'), 'action': 'create_declaration', 'context': context}

  call vjs#ipc#SendMessage(message, funcref('s:HandleCreateDeclarationResponse'))
endf

fun! s:HandleCreateDeclarationResponse(message) abort
  let reference = a:message.context.reference

  if !has_key(a:message, 'declaration')
    echohl Warn | echom reference .' is either already declared, or can not be declared in this context' | echohl None
    return
  endif

  let declaration_line = a:message.declaration.line - 1
  let indent = repeat(' ', a:message.declaration.column)
  let new_lines = []

  if getline(declaration_line + 1) != ''
    call insert(new_lines, '')
  endif

  call insert(new_lines, indent .'const '. reference . ' = ')

  call append(declaration_line, new_lines)

  execute ':'.(declaration_line + 1)

  startinsert!
endf
