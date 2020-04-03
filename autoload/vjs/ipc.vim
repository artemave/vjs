fun! vjs#ipc#ChSend(channel, msg)
  if has('nvim')
    return chansend(a:channel.id, a:msg)
  else
    return ch_sendraw(a:channel, a:msg)
  endif
endf

fun! vjs#ipc#JobGetChannel(channel)
  if has('nvim')
    return nvim_get_chan_info(a:channel)
  else
    return job_getchannel(a:channel)
  endif
endf

let s:s_path = resolve(expand('<sfile>:p:h:h'). '/..')

fun vjs#ipc#GetServerExecPath()
  let platform = substitute(system('uname'), '\n', '', '')

  if exists('g:vjs_test_env')
    return s:s_path .'/js_language_server.js'
  endif

  let server_bin = ''
  if platform == 'Darwin'
    let server_bin = s:s_path.'/dist/js_language_server'
  else
    let server_bin = 'node '.s:s_path.'/dist/js_language_server.js'
  endif

  return server_bin
endf
