# Js Balls

Essential for javascript productivity.

## What is this?

Vim plugin that brings along a bunch of helper functions to make development of javascript/node programs less painful.

Namely:

- autocomplete commons js requires
- list files that require current file
- list express routes
- fix linting errors

## Installation

Use [a plugin manager](https://github.com/VundleVim/Vundle.vim):

```vim script
Plugin 'artemave/js-balls'
```

## Usage

Js Balls registers "user defined completion" (`CTRL-X-u`) which gives you this:

Js Balls comes with no bindings, but does add the following commands:

**`:JsBallsListRequirers`** - show list of modules that require current file in quickfix window.

**`:JsBallsListRoutes`** - show list of express routes of current file in quickfix window.

**`:JsBallsLintFix`** - fix js linting. This will try `eslint`, `standard` and `prettier` before giving up. Note that it runs asynchronously so vim is never frozen.

### Example bindings

```vim script
au FileType {javascript,javascript.jsx} nnoremap <Leader>p :call JsBallsLintFix<cr>
au FileType {javascript,javascript.jsx} nnoremap <leader>R :call JsBallsListRequirers<cr>
```

## Running Plugin Tests

```
git clone https://github.com/junegunn/vader.vim.git
./run_tests
```
