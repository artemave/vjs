let g:vigun_commands = [
      \ {
      \   'pattern': 'spec.js$',
      \   'normal': './node_modules/.bin/mocha',
      \   'debug': './node_modules/.bin/electron-mocha --interactive --no-timeouts',
      \ },
      \]
