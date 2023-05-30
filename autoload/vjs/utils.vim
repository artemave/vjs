fun vjs#utils#indent(start_line, number_of_lines)
  let save_cursor = getcurpos()
  call setpos('.', [0, a:start_line, 0, 0])
  undojoin | silent execute 'normal' '='.a:number_of_lines.'j'
  call setpos('.', save_cursor)
endf
