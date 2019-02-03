if exists("g:vjs_loaded")
  finish
endif
let g:vjs_loaded = 1

if !executable('ag') || &grepprg !~ '^ag'
  throw "Vjs requies `ag` as `grepprg`"
  echo "Add this to .vimrc:"
  echo "set grepprg=ag \--vimgrep"
  echo "set grepformat=%f:%l:%c:%m"
endif

fun s:Debug(message)
  if exists("g:vjs_debug")
    echom a:message
  endif
endf

fun! s:ListRequirers()
  let grep_term = '(require\(.*\)\|^import)'
  execute 'silent lgrep!' "'".grep_term."'"
  redraw!

  let raw_results = getloclist(0)
  let result_entries = []
  let current_file_full_path = expand('%:p:r')

  for require in raw_results
    let match = matchlist(require.text, "['\"]".'\(\.\.\?\/.*\)'."['\"]")
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

      let module_base = fnamemodify(bufname(require.bufnr), ':p:h')

      let module_full_path = fnamemodify(module_base . '/' . module_path, ':p:r')
      let module_full_path_with_explicit_index = fnamemodify(module_base . '/' . module_path_with_explicit_index, ':p:r')

      if module_full_path == current_file_full_path || module_full_path_with_explicit_index == current_file_full_path
        call add(result_entries, require)
      endif
    endif
  endfor
  call setqflist([], 'r', {'items': result_entries, 'title': 'Dependencies of '.expand('%')})
  copen
endf

fun! s:LintFix()
  let command = './node_modules/.bin/eslint --fix'

  if &ft == 'typescript'
    let command = './node_modules/.bin/tslint --fix'
  else
    if executable('./node_modules/.bin/standard')
      let command = './node_modules/.bin/standard --fix'
    elseif executable('./node_modules/.bin/prettier')
      let command = './node_modules/.bin/prettier --write'
    endif
  endif
  :w
  silent let f = system(command.' '.expand('%'))
  checktime
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
    let cmd = 'ag --nogroup --nocolor --hidden -i -g "'.base.'"'

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

  fun! ToQuickFixEntry(i, line_number)
    let match = g:collected_match_results[a:i]
    let match = split(match, "\n")
    let match = map(match, function('StripLeadingSpaces'))
    let match = join(match, '')
    let match = substitute(match, '[ \t]', nr2char(160), 'g')

    return {'filename': expand('%'), 'lnum': a:line_number, 'text': match}
  endf

  let g:collected_match_results = []
  let rx = '\w\+\.\(get\|post\|put\|delete\|patch\|head\|options\|use\)(\_s*['."'".'"`][^'."'".'"`]\+['."'".'"`]'
  let starting_pos = getpos('.')

  call cursor(1, 1)

  let line_numbers = []
  while search(rx, 'W') > 0
    call add(line_numbers, line('.'))
  endwhile

  call FindAndCallForEachMatch(rx, 'CollectMatchResults')

  call setpos('.', starting_pos)

  let entries = map(line_numbers, function('ToQuickFixEntry'))
  call setqflist([], 'r', {'title': 'Express routes', 'items': entries})
  copen

  " hide filename and linenumber
  set conceallevel=2 concealcursor=nc
  syntax match llFileName /^[^|]*|[^|]*| / transparent conceal
endf

fun! s:ExtractVariable()
  let [line_end, column_end] = getpos("'>")[1:2]
  let end_of_line_selected = len(getline(line_end)) == column_end

  let @v = input('Variable name: ')
  if empty(@v)
    return
  endif

  normal gv
  normal "sx
  if empty(@s)
    return
  endif

  if end_of_line_selected == 1
    normal "vp
  else
    normal "vP
  endif

  " send buffer content and line('.') to js
  let code = join(getline(1,'$'), "\n")
  let context = {'current_indent_base': indent(line('.'))}
  let message = {'code': code, 'current_line': line('.'), 'query': 'findStatementStart', 'context': context}

  if exists('g:vjs_test_env')
    let response = system(s:s_path.'/js_language_server.js --single-run', json_encode(message))
    call InsertVarDeclaration(0, response)
  else
    let channel = job_getchannel(s:check_js_job)
    call ch_sendraw(channel, json_encode(message) . nr2char(10), {'callback': 'InsertVarDeclaration'})
  endif
endf

fun! InsertVarDeclaration(channel, response)
  let message = json_decode(a:response)
  let new_lines = split(repeat(' ', message.column) ."const ". @v ." = ". @s, "\n")
  call map(new_lines, {idx, line -> idx > 0 ? substitute(line, "^".repeat(' ', message.context.current_indent_base - message.column), '', '') : line})
  call append(message.line - 1, new_lines)
endf

let s:s_path = resolve(expand('<sfile>:p:h:h'))
if !exists('g:vjs_test_env')
  let s:check_js_job = job_start(s:s_path.'/js_language_server.js', {'cwd': s:s_path, 'err_cb': 'ErrorCb'})
endif

fun! ErrorCb(channel, message)
  echom 'VjsCheckJsIsValid channel error: '.string(a:message)
endf

autocmd FileType {javascript,javascript.jsx,typescript} setlocal omnifunc=VjsRequireComplete
com VjsLintFix call s:LintFix()
com VjsListRoutes call s:ListExpressRoutes()
com VjsListRequirers call s:ListRequirers()
com -range VjsExtractVariable call s:ExtractVariable()
