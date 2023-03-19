fun s:InsertMethodDeclaration(method_name, is_async)
  let method_type = luaeval('require"vjs".this_container_type()')

  if method_type == 'classMethod'
    let loc = luaeval('require"vjs".method_definition_end()')
  else
    let loc = luaeval('require"vjs".method_definition_start()')
  endif

  let declaration_line = loc.line
  let indent = repeat(' ', loc.column)
  let new_lines = []

  let async = ''
  if a:is_async
    let async = 'async '
  endif

  if method_type == 'classMethod'
    call add(new_lines, '')
    call add(new_lines, indent . async . a:method_name . '() {')
    call add(new_lines, indent .'}')

    call append(declaration_line, new_lines)
  else
    call add(new_lines, indent . async . a:method_name . '() {')
    call add(new_lines, indent .'},')
    call add(new_lines, '')

    call append(declaration_line - 1, new_lines)
  endif

  execute ':'.declaration_line
  normal f(l
  startinsert
endf

fun s:InsertClassDeclaration(class_name, with_constructor)
  let loc = luaeval('require"vjs".find_global_scope_start()')
  let declaration_line = loc.line - 1
  let indent = repeat(' ', loc.column)

  let new_lines = []

  call add(new_lines, indent .'class '. a:class_name . ' {')
  if a:with_constructor
    call add(new_lines, indent .'  constructor() {')
    call add(new_lines, indent .'  }')
  else
    call add(new_lines, indent .'  ')
  endif
  call add(new_lines, indent .'}')
  call add(new_lines, '')

  call append(declaration_line, new_lines)

  if a:with_constructor
    execute ':'.(declaration_line + 2)
    normal f(l
    startinsert
  else
    execute ':'.(declaration_line + 1)
    startinsert!
  endif
endf

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

    return s:InsertClassDeclaration(cword, constructor_arguments_match > -1)

  elseif match(current_line, '\Cthis. *'. cword .' *(') > -1
    let is_async = match(getline('.'), 'await \+\(this\.\)\? *'. cword) > -1
    return s:InsertMethodDeclaration(cword, is_async)

  elseif match(current_line, '\C'. cword .' *(') > -1
    let context.reference_type = 'function'
    let loc = luaeval('require"vjs".find_global_scope_start()')
  elseif match(current_line, '\Cthis. *'. cword) > -1
    let context.reference_type = 'property'
    let loc = luaeval('require"vjs".find_statement_start()')
  else
    let context.reference_type = 'variable'
    let loc = luaeval('require"vjs".find_statement_start()')
  endif

  return s:HandleCreateDeclarationResponse({ 'context': context, 'declaration': loc })
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
