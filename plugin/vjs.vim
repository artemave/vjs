if exists("g:vjs_loaded")
  finish
endif
let g:vjs_loaded = 1

fun! s:Debug(message)
  if exists("g:vjs_debug")
    echom a:message
  endif
endf

fun! s:SortByLength(s1, s2)
  return len(a:s1) == len(a:s2) ? 0 : len(a:s1) > len(a:s2) ? 1 : -1
endf

fun! s:SearchFilesCmd(base)
  if executable('rg')
    return 'rg --files | rg -i '.a:base
  elseif executable('ag')
    return 'ag --nogroup --nocolor --hidden -i -g "'.a:base.'"'
  else
    return 'find . -type f -path "*'.a:base.'*"'
  endif
endf

fun! vjs#ModuleComplete(findstart, base)
  if a:findstart
    " locate the start of the word
    let line = getline('.')
    let end = col('.') - 1
    let start = end
    while start > 0 && line[start - 1] =~ "[^'\"]"
      let start -= 1
    endwhile

    let base = substitute(line[start : end - 1], '^[./]*', '', '')
    let cmd = s:SearchFilesCmd(base)

    let matches = systemlist(cmd)

    if g:vjs_dumb_require_complete
      let s:js_require_complete_matches = matches
    else
      let s:js_require_complete_matches = map(
            \ matches,
            \ {i, val -> substitute(val, '\(\/index\)\?.\([tj]sx\?\|mjs\)$', '', '')}
            \ )
    endif

    return start
  else
    " find files matching with "a:base"
    let res = []
    for m in s:js_require_complete_matches
      if m =~ substitute(a:base, '^[./]*', '', '')
        let current_path_entries = split(expand('%:h'), '/')
        let m_path_entries = split(m, '/')

        let path_prefix = []
        let i = 0
        while i < len(current_path_entries)
          let current_path_entry = current_path_entries[i]

          if len(m_path_entries) > i
            let m_path_entry = m_path_entries[i]
          else
            let m_path_entry = ''
          endif

          if current_path_entry == m_path_entry
            let m = substitute(m, '^'.m_path_entry.'\/', '', '')
          else
            call add(path_prefix, '..')
          endif
          let i = i + 1
        endwhile

        if empty(path_prefix)
          call add(res, './'.m)
        else
          call add(res, join(path_prefix, '/').'/'.m)
        endif
      endif
    endfor
    return sort(res, "s:SortByLength")
  endif
endf

fun! s:ListExpressRoutes()
  fun! StripLeadingSpaces(i, val)
    let newVal = substitute(a:val, '^[ \t]*', '', '')
    return newVal
  endf

  fun! FindAndCallForEachMatch(regex, func_name)
    let expr = ':keeppatterns %s/' . a:regex . '/\=' . a:func_name. '(submatch(0))/gn'
    execute expr
  endf

  fun! CollectMatchResults(match)
    call add(g:collected_match_results, a:match)
  endf

  fun! ToQuickFixEntry(i, line_number)
    let match = g:collected_match_results[a:i]
    let match = split(match, "\n")
    let match = map(match, function('StripLeadingSpaces'))
    let match = join(match, '')
    let match = substitute(match, '[ \t]', nr2char(160), 'g')

    return {'filename': expand('%'), 'lnum': a:line_number, 'text': match}
  endf

  let g:collected_match_results = []
  let rx = '\w\+\.\(get\|post\|put\|delete\|patch\|head\|options\|use\)(\_s*[''"`][^''"`]\+[''"`]'
  let starting_pos = getpos('.')

  call cursor(1, 1)

  let line_numbers = []
  while search(rx, 'W') > 0
    call add(line_numbers, line('.'))
  endwhile

  call FindAndCallForEachMatch(rx, 'CollectMatchResults')

  call setpos('.', starting_pos)

  let entries = map(line_numbers, function('ToQuickFixEntry'))
  call setqflist([], ' ', {'title': 'Express routes', 'items': entries})
  copen

  " hide filename and linenumber
  set conceallevel=2 concealcursor=nc
  syntax match llFileName /^[^|]*|[^|]*| / transparent conceal
endf

if !exists('g:vjs_dumb_require_complete')
  let g:vjs_dumb_require_complete = 0
endif

autocmd FileType javascript setlocal includeexpr=vjs#imports#ResolvePackageImport(v:fname)
autocmd FileType javascript setlocal isfname+=@-@

com VjsListRoutes call s:ListExpressRoutes()
com VjsRenameFile call vjs#imports#RenameFile()
com VjsListDependents call vjs#imports#ListDependents()
com VjsExtractDeclarationIntoFile call vjs#extract#ExtractDeclarationIntoFile()
com VjsCreateDeclaration call vjs#declare#CreateDeclaration()
com -range VjsExtractVariable call vjs#extract#ExtractVariable()
com -range VjsExtractLocalFunction call vjs#extract#ExtractLocalFunction()
com -range VjsExtractFunctionOrMethod call vjs#extract#ExtractFunctionOrMethod()

" TODO: require_language javascript
