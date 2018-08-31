# Vjs [![Build Status](https://travis-ci.org/artemave/vjs.svg?branch=master)](https://travis-ci.org/artemave/vjs)

Essential for javascript productivity.

## What is this?

Vim plugin that brings along a bunch of helper functions to make development of javascript/node programs less painful.

Namely:

- autocomplete commons js requires
- list files that require current file
- list express routes
- fix linting errors

For testing related goodies check out [vigun](https://github.com/artemave/vigun).

## Installation

Use [a plugin manager](https://github.com/VundleVim/Vundle.vim):

```vim script
Plugin 'artemave/js-balls'
``` 

[ag](https://github.com/ggreer/the_silver_searcher) is required.

## Usage

Vjs registers "user defined completion" (`CTRL-X-u`) which gives you this:

![2018-03-12 23 40 39](https://user-images.githubusercontent.com/23721/38147456-b25bad1a-3452-11e8-984f-f609de469211.gif)

Vjs comes with no bindings, but does add the following commands:

**`:VjsListRequirers`** - show list of modules that require current file in quickfix window.

![2018-03-30 19 51 28](https://user-images.githubusercontent.com/23721/38147735-d9631104-3453-11e8-91fa-67db2bf13055.gif)

**`:VjsListRoutes`** - show list of express routes of current file in quickfix window.

![2018-03-30 19 55 02](https://user-images.githubusercontent.com/23721/38147868-5995de2e-3454-11e8-9f87-8178004862d9.gif)

**`:VjsLintFix`** - fix js linting. This will try `eslint`, `standard` and `prettier` before giving up. Note that it runs asynchronously so vim is never frozen.

![2018-03-30 19 56 59](https://user-images.githubusercontent.com/23721/38147921-9ff6de22-3454-11e8-810d-596451d3765d.gif)

### Example bindings

```vim script
au FileType {javascript,javascript.jsx} nnoremap <Leader>p :call VjsLintFix<cr>
au FileType {javascript,javascript.jsx} nnoremap <leader>R :call VjsListRequirers<cr>
```

## Running Plugin Tests

```
git clone https://github.com/junegunn/vader.vim.git
./run_tests
```
