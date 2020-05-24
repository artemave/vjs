let g:vigun_commands = [
      \ {
      \   'pattern': '_spec.js$',
      \   'normal': './node_modules/.bin/mocha',
      \   'debug': './node_modules/.bin/mocha --inspect-brk --no-timeouts',
      \ },
      \ {
      \   'pattern': 'test/.*.vader$',
      \   'normal': './run_tests'
      \ }
      \]
