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

    if g:vjs_es_modules_complete
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

if !exists('g:vjs_es_modules_complete')
  let g:vjs_es_modules_complete = 0
endif

autocmd FileType javascript setlocal includeexpr=vjs#imports#ResolvePackageImport(v:fname)
autocmd FileType javascript setlocal isfname+=@-@

com VjsRenameFile call vjs#imports#RenameFile()
com VjsListDependents call vjs#imports#ListDependents()
com VjsExtractDeclarationIntoFile call vjs#extract#ExtractDeclarationIntoFile()
com VjsCreateDeclaration call vjs#declare#CreateDeclaration()
com -range VjsExtractVariable call vjs#extract#ExtractVariable()
com -range VjsExtractLocalFunction call vjs#extract#ExtractLocalFunction()
com -range VjsExtractFunctionOrMethod call vjs#extract#ExtractFunctionOrMethod()
