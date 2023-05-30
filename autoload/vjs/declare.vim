fun s:InsertMethodDeclaration(method_name, is_async)
  let [type; _] = luaeval('require"vjs".extracted_type_and_loc({ bound = true })')

  if type == 'method'
    let loc = luaeval('require"vjs".method_definition_end()')
  else
    let loc = luaeval('require"vjs".method_definition_start()')
  endif

  let declaration_line = loc.line
  let new_lines = []

  let async = ''
  if a:is_async
    let async = 'async '
  endif

  if type == 'method'
    call add(new_lines, '')
    call add(new_lines, async . a:method_name . '() {')
    call add(new_lines, '}')
  else
    call add(new_lines, async . a:method_name . '() {')
    call add(new_lines, '},')
    call add(new_lines, '')

    let declaration_line -= 1
  endif

  call append(declaration_line, new_lines)
  call vjs#utils#indent(declaration_line, len(new_lines))
  execute ':'.declaration_line

  normal f(l
  startinsert
endf

fun s:InsertClassDeclaration(class_name, with_constructor)
  let loc = luaeval('require"vjs".find_closest_global_scope()')
  let declaration_line = loc.line - 1

  let new_lines = []

  call add(new_lines, 'class '. a:class_name . ' {')
  if a:with_constructor
    call add(new_lines, '  constructor() {')
    call add(new_lines, '  }')
  else
    call add(new_lines, '  ')
  endif
  call add(new_lines, '}')
  call add(new_lines, '')

  call append(declaration_line, new_lines)
  call vjs#utils#indent(declaration_line, len(new_lines))

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
    let loc = luaeval('require"vjs".find_closest_global_scope()')
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
  let new_lines = []

  let async = ''
  if match(getline('.'), 'await \+\(this\.\)\? *'. reference) > -1
    let async = 'async '
  endif

  if reference_type == 'variable'
    call add(new_lines, 'const '. reference . ' = ')
  elseif reference_type == 'function'
    call add(new_lines, async .'function '. reference . '() {')
    call add(new_lines, '}')
  elseif reference_type == 'class'
    call add(new_lines, 'class '. reference . ' {')
    call add(new_lines, '  ')
    call add(new_lines, '}')
  else
    call add(new_lines, 'class '. reference . ' {')
    call add(new_lines, '  constructor() {')
    call add(new_lines, '  }')
    call add(new_lines, '}')
  endif

  call add(new_lines, '')

  call append(declaration_line, new_lines)
  call vjs#utils#indent(declaration_line, len(new_lines))

  " TODO: tidy up
  if reference_type == 'variable'
    execute ':'.declaration_line
    startinsert!
  elseif reference_type == 'class'
    execute ':'.(declaration_line + 1)
    startinsert!
  else
    let jump = 0
    if reference_type == 'class_with_constructor_arguments'
      let jump = 1
    endif
    execute ':'.(declaration_line + jump)
    normal f(l
    startinsert
  endif
endf
