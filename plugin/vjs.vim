if exists("g:vjs_loaded")
  finish
endif
let g:vjs_loaded = 1

fun! s:Debug(message)
  if exists("g:vjs_debug")
    echom a:message
  endif
endf

fun! s:ListDependents()
  call s:PrepareDependantsList()
  copen
endf

fun! s:PrepareDependantsList()
  " \x27 is ascii for single quote
  let grep_term = '(require\(.*\)\|^import "\|^import \x27\| from )'
  execute 'silent grep!' "'".grep_term."'"
  redraw!

  let raw_results = getqflist()
  let result_entries = []
  let current_file_full_path = expand('%:p:r')

  for require in raw_results
    let match = matchlist(require.text, "['\"]".'\(\.\.\?\/.*\|\~.*\|\.\.\?\)'."['\"]")
    if len(match) > 0
      let module_path = match[1]
      let module_path_with_explicit_index = ''

      if match(module_path, '\.$') != -1
        let module_path = module_path . '/index'
      elseif match(module_path, '\/$') != -1
        let module_path = module_path . 'index'
      elseif match(module_path, 'index\(\.[tj]sx\?\)\?$') == -1
        let module_path_with_explicit_index = module_path . '/index'
      endif

      if match(module_path, '^\~') != -1
        " drop leading `~/`
        let module_path = module_path[2:]
        let module_base = getcwd()
      else
        let module_base = fnamemodify(bufname(require.bufnr), ':p:h')
      endif

      let module_full_path = fnamemodify(module_base . '/' . module_path, ':p:r')
      let module_full_path_with_explicit_index = fnamemodify(module_base . '/' . module_path_with_explicit_index, ':p:r')

      if module_full_path == current_file_full_path || module_full_path_with_explicit_index == current_file_full_path
        call add(result_entries, require)
      endif
    endif
  endfor
  call setqflist([], ' ', {'items': result_entries, 'title': 'Modules that import '.expand('%')})
endf

fun! s:LintFix()
  let command = './node_modules/.bin/eslint --fix'

  if executable('./node_modules/.bin/standard')
    let command = './node_modules/.bin/standard --fix'
  elseif executable('./node_modules/.bin/prettier')
    let command = './node_modules/.bin/prettier --write'
  endif
  :w
  silent let f = system(command.' '.expand('%'))
  checktime
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

fun! VjsRequireComplete(findstart, base)
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

    let g:js_require_complete_matches = map(
          \ systemlist(cmd),
          \ {i, val -> substitute(val, '\(\/index\)\?.[tj]sx\?$', '', '')}
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

fun! s:RenameFile()
  let old_name = expand('%:t:r')
  let current_line = line('.')
  let new_name = input('New name: ', '', 'file')

  if match(new_name, '\/') == -1
    let full_new_name_path = fnamemodify(expand('%:h') . '/'. new_name, ':p')
  else
    let full_new_name_path = fnamemodify(getcwd() . '/'. new_name, ':p')
  endif

  if !exists('g:vjs_test_env')
    if rename(expand('%:p'), full_new_name_path) != 0
      return
    end
  endif

  call s:PrepareDependantsList()

  let dependants = getqflist()

  let full_new_name_path_parts = split(full_new_name_path, '/')

  for require in dependants
    let import_path_parts = []
    let fname = bufname(require.bufnr)
    let dependant_full_path_parts = split(fnamemodify(fname, ':p'), '/')

    let max_len = max([len(dependant_full_path_parts), len(full_new_name_path_parts)])

    let idx = 0
    let paths_diverged = v:false
    let import_path_parts = []

    while idx < max_len
      if idx >= len(full_new_name_path_parts)
        call insert(import_path_parts, '..', 0)
        let idx = idx + 1
        continue
      endif

      if idx >= len(dependant_full_path_parts)
        call add(import_path_parts, full_new_name_path_parts[idx])
        let idx = idx + 1
        continue
      endif

      if dependant_full_path_parts[idx] != full_new_name_path_parts[idx] || paths_diverged
        if paths_diverged
          call insert(import_path_parts, '..', 0)
        end
        let paths_diverged = v:true

        call add(import_path_parts, full_new_name_path_parts[idx])
      endif

      let idx = idx + 1
    endwhile

    if import_path_parts[0] != '..'
      call insert(import_path_parts, '.', 0)
    endif

    let new_import_path = fnamemodify(join(import_path_parts, '/'), ':r')

    let new_text_pattern = '\(["'']\).\+["'']'
    let new_text_replacement = '\1'. new_import_path .'\1'

    let new_text = substitute(require.text, new_text_pattern, new_text_replacement, '')
    let require.text = new_text

    let cmd = 'sed -r -i "'. require.lnum .'s/'. escape(new_text_pattern, '/\"') .'/'. escape(new_text_replacement, '/\"') .'/" '. fname
    if !exists('g:vjs_test_env')
      silent call system(cmd)
    endif
  endfor

  if !exists('g:vjs_test_env')
    silent bwipeout!
    execute 'edit +'. current_line .' '. full_new_name_path
  endif

  call setqflist([], 'r', {'title': 'Imports updated', 'items': dependants})
  copen
endf

if !exists('g:vjs_tags_enabled')
  let g:vjs_tags_enabled = 1
endif

if !exists('g:vjs_tags_regenerate_at_start')
  let g:vjs_tags_regenerate_at_start = 1
endif

if !exists('g:vjs_tags_ignore')
  let g:vjs_tags_ignore = []
endif

autocmd FileType {javascript,javascript.jsx,typescript} call vjs#ipc#StartJsRefactoringServer()
autocmd FileType {javascript,javascript.jsx} call vjs#ipc#StartJsTagsServer()
" TODO: how to avoid global name with omnifunc?
autocmd FileType {javascript,javascript.jsx,typescript} setlocal omnifunc=VjsRequireComplete

com VjsLintFix call s:LintFix()
com VjsRenameFile call s:RenameFile()
com VjsListRoutes call s:ListExpressRoutes()
com VjsListDependents call s:ListDependents()
com -range VjsExtractVariable call vjs#extract#ExtractVariable()
com -range VjsExtractLocalFunction call vjs#extract#ExtractFunctionOrMethod('local')
com -range VjsExtractFunctionOrMethod call vjs#extract#ExtractFunctionOrMethod()
