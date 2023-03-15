fun! vjs#declare#CreateDeclaration() abort
  let cword = expand('<cword>')
  let current_line = getline('.')

  if cword == 'this'
    return
  endif

  let context = { 'reference': cword }

  if cword =~ '\C^[A-Z]'
    let constructor_arguments_match = match(current_line, '\C'. cword .' *([^)]')

    if constructor_arguments_match > -1
      let context.reference_type = 'class_with_constructor_arguments'
    else
      let context.reference_type = 'class'
    endif
  elseif match(current_line, '\Cthis. *'. cword .' *(') > -1
    let context.reference_type = 'method'
  elseif match(current_line, '\C'. cword .' *(') > -1
    let context.reference_type = 'function'
  elseif match(current_line, '\Cthis. *'. cword) > -1
    let context.reference_type = 'property'
    let loc = luaeval('require"vjs".find_statement_start()')
    return s:HandleCreateDeclarationResponse({ 'context': context, 'declaration': loc })
  else
    let refs = luaeval('require"vjs".references()')
    if len(refs) > 0
      return
    endif

    let context.reference_type = 'variable'
    let loc = luaeval('require"vjs".find_statement_start()')
    return s:HandleCreateDeclarationResponse({ 'context': context, 'declaration': loc })
  endif

  let code = join(getline(1, '$'), "\n")
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

  let async = ''
  if match(getline('.'), 'await \+\(this\.\)\? *'. reference) > -1
    let async = 'async '
  endif

  if reference_type == 'variable'
    call add(new_lines, indent .'const '. reference . ' = ')
  elseif reference_type == 'property'
    call add(new_lines, indent .'this.'. reference . ' = ')
  elseif reference_type == 'function'
    call add(new_lines, indent . async .'function '. reference . '() {')
    call add(new_lines, indent .'}')
  elseif reference_type == 'classMethod'
    call add(new_lines, '')
    call add(new_lines, indent . async . reference . '() {')
    call add(new_lines, indent .'}')
  elseif reference_type == 'objectMethod'
    call add(new_lines, indent . async . reference . '() {')
    call add(new_lines, indent .'},')
  elseif reference_type == 'class'
    call add(new_lines, indent .'class '. reference . ' {')
    call add(new_lines, indent .'  ')
    call add(new_lines, indent .'}')
  else
    call add(new_lines, indent .'class '. reference . ' {')
    call add(new_lines, indent . '  constructor() {')
    call add(new_lines, indent . '  }')
    call add(new_lines, indent .'}')
  endif

  " insert blank line after new declaration if there isn't one already
  if reference_type != 'classMethod' && getline(declaration_line + 1) != ''
    call add(new_lines, '')
  endif

  " class method is inserted in the end of class body
  if reference_type == 'classMethod'
    call append(declaration_line + 1, new_lines)
  else
    call append(declaration_line, new_lines)
  endif

  if reference_type == 'variable' || reference_type == 'property'
    execute ':'.(declaration_line + 1)
    startinsert!
  elseif reference_type == 'class'
    execute ':'.(declaration_line + 2)
    startinsert!
  else
    let jump = 1
    if reference_type == 'class_with_constructor_arguments'
      let jump = 2
    elseif reference_type == 'classMethod'
      let jump = 3
    endif
    execute ':'.(declaration_line + jump)
    normal f(l
    startinsert
  endif
endf
