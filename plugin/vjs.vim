if exists("g:vjs_loaded")
  finish
endif
let g:vjs_loaded = 1

fun! s:Debug(message)
  if exists("g:vjs_debug")
    echom a:message
  endif
endf

fun! s:ListRequirers()
  let grep_term = '(require\(.*\)\|^import )'
  execute 'silent grep!' "'".grep_term."'"
  redraw!

  let raw_results = getqflist()
  let result_entries = []
  let current_file_full_path = expand('%:p:r')

  for require in raw_results
    let match = matchlist(require.text, "['\"]".'\(\.\.\?\/.*\|\~.*\)'."['\"]")
    if len(match) > 0
      let module_path = match[1]
      let module_path_with_explicit_index = ''

      " TODO: missing case? require('.')
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
  copen
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

fun! s:ExtractFunction()
  " TODO: restore @v
  let @v = input('Function name: ')
  if empty(@v)
    return
  endif

  let code = join(getline(1,'$'), "\n")
  let context = {'action': 'extract_function'}
  let message = {'code': code, 'current_line': line('.'), 'query': 'findStatementStart', 'context': context}

  if exists('g:vjs_test_env')
    let response = system(s:s_path.'/js_language_server.js refactoring --single-run', json_encode(message))
    call s:RefactoringResponseHandler(0, response)
  else
    let channel = s:JobGetChannel(s:refactoring_server_job)
    call ChSend(channel, json_encode(message) . nr2char(10))
  endif
endf

fun! s:ExtractVariable()
  let [selection_start_line, selection_start_column] = getpos("'<")[1:2]
  let text_before_selection_start = getline(selection_start_line)[0:selection_start_column - 2]
  let property_name_match = matchlist(text_before_selection_start, '\(\w\+\) *: *$')
  let property_name = ''
  if len(property_name_match) > 1
    let property_name = property_name_match[1]
  endif

  let @v = input('Variable name: ', property_name)
  if empty(@v)
    return
  endif

  " send buffer content and line('.') to js
  let code = join(getline(1,'$'), "\n")
  let context = {'property_name': property_name, 'action': 'extract_variable'}
  let message = {'code': code, 'current_line': line('.'), 'query': 'findStatementStart', 'context': context}

  if exists('g:vjs_test_env')
    let response = system(s:s_path.'/js_language_server.js refactoring --single-run', json_encode(message))
    call s:RefactoringResponseHandler(0, response)
  else
    let channel = s:JobGetChannel(s:refactoring_server_job)
    call ChSend(channel, json_encode(message) . nr2char(10))
  endif
endf

fun! ChSend(channel, msg)
  if has('nvim')
    return chansend(a:channel.id, a:msg)
  else
    return ch_sendraw(a:channel, a:msg)
  endif
endf

fun! s:JobGetChannel(channel)
  if has('nvim')
    return nvim_get_chan_info(a:channel)
  else
    return job_getchannel(a:channel)
  endif
endf

fun! s:RefactoringResponseHandler(channel, response, ...) abort
  let message = json_decode(a:response)

  let indent = repeat(' ', message.column)

  if message.context.action == 'extract_variable'
    let current_indent_base = indent(line('.'))

    let property_name = message.context.property_name

    let selection_start_line = getpos("'<")[1]
    let [selection_end_line, selection_end_column] = getpos("'>")[1:2]
    let last_selected_line_is_selected_until_the_end = selection_end_column > 999999 || len(getline(selection_end_line)) == selection_end_column

    normal gv
    normal "sx

    if @v == property_name
      let new_line = substitute(getline(selection_start_line), property_name.' *: *', property_name, '')
      call setline(selection_start_line, new_line)
    else
      if last_selected_line_is_selected_until_the_end
        undojoin | normal "vp
      else
        undojoin | normal "vP
      endif
    endif

    let new_lines = split(indent ."const ". @v ." = ". @s, "\n")
    call map(new_lines, {idx, line -> idx > 0 ? substitute(line, "^".repeat(' ', current_indent_base - message.column), '', '') : line})

  elseif message.context.action == 'extract_function'
    normal gv
    normal "sx

    let is_async = match(@s, '\<await ')

    let first_new_line = 'function '. @v .'() {'
    if is_async > -1
      let first_new_line = 'async '. first_new_line
    endif

    let @v = @v ."()"
    if is_async > -1
      let @v = 'await '. @v
    endif
    undojoin | normal "vp
    undojoin | normal ==

    if match(@s, '\n$') > -1
      undojoin | call append(line('.'), '')
    endif

    let new_lines = [first_new_line]
    call extend(new_lines, split(@s, "\n"))
    call map(new_lines, {_, line -> repeat(' ', &shiftwidth) . line})
    call extend(new_lines, [indent .'}', ''])
  else
    throw 'Unknown action '. message.context.action
  endif

  undojoin | call append(message.line - 1, new_lines)
endf

let s:s_path = resolve(expand('<sfile>:p:h:h'))

fun! s:ErrorCb(channel, message, ...)
  echom 'Vjs language server error: '.string(a:message)
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

fun GetServerExecPath()
  let platform = substitute(system('uname'), '\n', '', '')

  let server_bin = ''
  if platform == 'Darwin'
    let server_bin = s:s_path.'/dist/js_language_server'
  else
    let server_bin = 'node '.s:s_path.'/dist/js_language_server.js'
  endif
  return server_bin
endf

fun! s:StartJsRefactoringServer()
  if !exists('g:vjs_test_env') && !exists('s:refactoring_server_job')
    let s:refactoring_server_job = JobStart(GetServerExecPath().' refactoring', {'err_cb': function('s:ErrorCb'), 'out_cb': function('s:RefactoringResponseHandler')})
  endif
endf

fun! s:StartJsTagsServer()
  if !exists('g:vjs_test_env') && !exists('s:tags_server_job') && g:vjs_tags_enabled == 1
    let tags_job_cmd = GetServerExecPath().' tags'
    if g:vjs_tags_regenerate_at_start == 0
      let tags_job_cmd = tags_job_cmd.' --update'
    endif
    for path in g:vjs_tags_ignore
      let tags_job_cmd = tags_job_cmd.' --ignore '.path
    endfor

    " without `out_cb` must be present
    let s:tags_server_job = JobStart(tags_job_cmd, {'cwd': getcwd(), 'err_cb': 's:ErrorCb', 'out_cb': 's:ErrorCb', 'pty': 1})
  end
endf

fun! JobStart(cmd, options)
  if has('nvim')
    let options = a:options
    let options.on_stdout = options.out_cb
    let options.on_stderr = options.err_cb
    " let options.stdout_buffered = v:true
    " let options.stderr_buffered = v:true
    return jobstart(a:cmd, options)
  else
    return job_start(a:cmd, a:options)
  endif
endf

autocmd FileType {javascript,javascript.jsx,typescript} call s:StartJsRefactoringServer()
autocmd FileType {javascript,javascript.jsx} call s:StartJsTagsServer()

autocmd FileType {javascript,javascript.jsx,typescript} setlocal omnifunc=VjsRequireComplete
com VjsLintFix call s:LintFix()
com VjsListRoutes call s:ListExpressRoutes()
com VjsListRequirers call s:ListRequirers()
com -range VjsExtractVariable call s:ExtractVariable()
com -range VjsExtractFunction call s:ExtractFunction()
