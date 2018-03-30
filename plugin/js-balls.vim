if exists("g:jsballs_loaded")
  finish
endif
let g:jsballs_loaded = 1

if !executable('ag') || &grepprg !~ '^ag'
  throw "Js Balls requies `ag` as `grepprg`"
  echo "Add this to .vimrc:"
  echo "set grepprg=ag \--vimgrep"
  echo "set grepformat=%f:%l:%c:%m"
endif

fun s:Debug(message)
  if exists("g:jsballs_debug")
    echom a:message
  endif
endf

fun! s:ListRequirers()
  let grep_term = 'require\(.*\)'
  execute 'silent grep!' "'".grep_term."'"
  redraw!

  let results = getqflist()
  call setqflist([])

  for require in results
    let match = matchlist(require.text, "['\"]".'\(\.\.\?\/.*\)'."['\"]")
    if len(match) > 0
      let module_path = match[1]
      let module_path_with_explicit_index = ''

      if match(module_path, '\.$') != -1
        let module_path = module_path . '/index'
      elseif match(module_path, '\/$') != -1
        let module_path = module_path . 'index'
      elseif match(module_path, 'index\(\.jsx\?\)\?$') == -1
        let module_path_with_explicit_index = module_path . '/index'
      endif

      let module_base = fnamemodify(bufname(require.bufnr), ':p:h')

      let current_file_full_path = expand('%:p:r')
      let module_full_path = fnamemodify(module_base . '/' . module_path, ':p:r')
      let module_full_path_with_explicit_index = fnamemodify(module_base . '/' . module_path_with_explicit_index, ':p:r')

      if module_full_path == current_file_full_path || module_full_path_with_explicit_index == current_file_full_path
        caddexpr bufname(require.bufnr) . ':' . require.lnum . ':' .require.text
      endif
    endif
  endfor
  copen
endf

fun! s:LintFix()
  let command = 'eslint --fix'
  if executable('standard')
    let command = 'standard --fix'
  elseif executable('prettier')
    let command = 'prettier --write'
  endif
  :w
  silent let f = system(command.' '.expand('%'))
  checktime
endf

fun! JsBallsRequireComplete(findstart, base)
  if a:findstart
    " locate the start of the word
    let line = getline('.')
    let end = col('.') - 1
    let start = end
    while start > 0 && line[start - 1] =~ "[^'\"]"
      let start -= 1
    endwhile

    let base = substitute(line[start : end - 1], '^[./]*', '', '')
    let cmd = 'ag --nogroup --nocolor --hidden -i -g "'.base.'"'

    let g:js_require_complete_matches = map(
          \ systemlist(cmd),
          \ {i, val -> substitute(val, '\(\/index\)\?.jsx\?$', '', '')}
          \ )

    return start
  else
    " find files matching with "a:base"
    let res = []
    for m in g:js_require_complete_matches
      if m =~ substitute(a:base, '^[./]*', '', '')
        let current_path_entries = split(expand('%:h'), '/')
        let m_path_entries = split(m, '/')

        let path_prefix = []
        let i = 0
        while i < len(current_path_entries)
          let current_path_entry = current_path_entries[i]
          let m_path_entry = m_path_entries[i]
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
    return res
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

  fun! AddMatchToQuickFix(i, line_number)
    let match = g:collected_match_results[a:i]
    let match = split(match, "\n")
    let match = map(match, function('StripLeadingSpaces'))
    let match = join(match, '')
    let match = substitute(match, '[ \t]', nr2char(160), 'g')

    let expr = printf('%s:%s:%s', expand("%"), a:line_number, match)
    caddexpr expr
  endf

  let g:collected_match_results = []
  let rx = '\w\+\.\(get\|post\|put\|delete\|patch\|head\|options\|use\)(\_s*['."'".'"`][^'."'".'"`]\+['."'".'"`]'
  let starting_pos = getpos('.')

  call setqflist([])
  call cursor(1, 1)

  let line_numbers = []
  while search(rx, 'W') > 0
    call add(line_numbers, line('.'))
  endwhile

  call FindAndCallForEachMatch(rx, 'CollectMatchResults')
  call map(line_numbers, function('AddMatchToQuickFix'))

  call setpos('.', starting_pos)
  copen

  " hide filename and linenumber
  set conceallevel=2 concealcursor=nc
  syntax match llFileName /^[^|]*|[^|]*| / transparent conceal
endf

autocmd FileType {javascript,javascript.jsx} setlocal completefunc=JsBallsRequireComplete
com JsBallsLintFix call s:LintFix()
com JsBallsListRoutes call s:ListExpressRoutes()
com JsBallsListRequirers call s:ListRequirers()
