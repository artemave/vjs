let s:callbacks = {}

fun! s:messageId(message)
  return a:message.action .'__'. localtime()
endf

fun! vjs#ipc#SendMessage(message, callback)
  let a:message.filetype = &filetype

  if !has_key(a:message, 'context')
    let a:message.context = {}
  endif

  let message_id = s:messageId(a:message)
  let a:message.context.message_id = message_id
  let s:callbacks[message_id] = a:callback

  if exists('g:vjs_test_env')
    let response = system(s:GetServerExecPath().' refactoring --single-run', json_encode(a:message))
    call vjs#ipc#RefactoringResponseHandler(0, response)
  else
    let channel = s:JobGetChannel(s:refactoring_server_job)
    call s:ChSend(channel, json_encode(a:message) . nr2char(10))
  endif
endf

fun! vjs#ipc#RefactoringResponseHandler(channel, response, ...) abort
  let message = json_decode(a:response)

  if has_key(message, 'error')
    " TODO: cleanup callback
    throw a:response
  endif

  let Callback = remove(s:callbacks, message.context.message_id)
  call Callback(message)
endf

fun! vjs#ipc#StartJsRefactoringServer()
  if !exists('g:vjs_test_env') && !exists('s:refactoring_server_job')
    let s:refactoring_server_job = s:JobStart(s:GetServerExecPath().' refactoring', {'err_cb': function('vjs#ipc#VjsErrorCb'), 'out_cb': function('vjs#ipc#RefactoringResponseHandler')})
  endif
endf

fun! vjs#ipc#StartJsTagsServer()
  if !exists('g:vjs_test_env') && !exists('s:tags_server_job') && g:vjs_tags_enabled == 1
    let tags_job_cmd = s:GetServerExecPath().' tags'
    if g:vjs_tags_regenerate_at_start == 0
      let tags_job_cmd = tags_job_cmd.' --update'
    endif
    for path in g:vjs_tags_ignore
      let tags_job_cmd = tags_job_cmd.' --ignore '.path
    endfor

    let s:tags_server_job = s:JobStart(tags_job_cmd, {'cwd': getcwd(), 'err_cb': 'vjs#ipc#VjsErrorCb', 'out_cb': 'vjs#ipc#VjsErrorCb', 'pty': 1})
  end
endf

fun! s:ChSend(channel, msg)
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

fun! vjs#ipc#VjsErrorCb(channel, message, ...)
  echom 'Vjs language server error: '.string(a:message)
endf

fun! s:JobStart(cmd, options)
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

let s:s_path = resolve(expand('<sfile>:p:h:h'). '/..')

fun s:GetServerExecPath()
  return s:s_path .'/js_language_server.js'
endf
