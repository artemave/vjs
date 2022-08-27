let g:vigun_mappings = [
      \ {
      \   'pattern': '_spec.js$',
      \   'all': './node_modules/.bin/mocha #{file}',
      \   'debug-nearest': './node_modules/.bin/mocha --inspect-brk --no-timeouts --fgrep #{nearest_test} #{file}',
      \ },
      \ {
      \   'pattern': 'test/.*.vader$',
      \   'all': './run_tests #{file}'
      \ }
      \]
