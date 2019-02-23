# Vjs <!-- [![CircleCI](https://circleci.com/gh/artemave/vjs.svg?style=svg)](https://circleci.com/gh/artemave/vjs) -->

Essential for javascript productivity.

## What is this?

Vim plugin that brings along a bunch of features to make development of javascript/node programs less painful.

Namely:

- autocomplete `require`/`import` paths
- list files that require current file
- fix linting errors (without blocking vim)
- extract variable
- auto generating and keeping up to date `tags` file
- list Express routes

For testing related goodies check out [vigun](https://github.com/artemave/vigun).

## Installation

Use [a plugin manager](https://github.com/VundleVim/Vundle.vim):

```vim script
Plugin 'artemave/vjs'
``` 

[ag](https://github.com/ggreer/the_silver_searcher) is required.

## Usage

#### Complete require paths

Vjs registers an `omnifunc` for `require`/`import` path completion - `CTRL-X CTRL-O` - which gives you this:

![2018-03-12 23 40 39](https://user-images.githubusercontent.com/23721/38147456-b25bad1a-3452-11e8-984f-f609de469211.gif)

Vjs comes with no bindings, but does add the following commands:

#### `:VjsListRequirers`

Shows list of modules that require current file in quickfix window. Supports both commonJS and ES6 modules.

![2018-03-30 19 51 28](https://user-images.githubusercontent.com/23721/38147735-d9631104-3453-11e8-91fa-67db2bf13055.gif)

#### `:VjsListRoutes`

Shows list of express routes of current file in quickfix window.

![2018-03-30 19 55 02](https://user-images.githubusercontent.com/23721/38147868-5995de2e-3454-11e8-9f87-8178004862d9.gif)

#### `:VjsLintFix`

Fixes js/typescript lint errors. For js it will try `eslint`, `standard` and `prettier` (in that order). Note that it runs asynchronously so vim is never frozen.

![2018-03-30 19 56 59](https://user-images.githubusercontent.com/23721/38147921-9ff6de22-3454-11e8-810d-596451d3765d.gif)

#### `:'<,'>VjsExtractVariable`

Extracts selected code into a variable.

![2019-02-03 22 38 16](https://user-images.githubusercontent.com/23721/52183335-27da2280-2807-11e9-84bd-e51e424d0872.gif)

### Configuration

`g:vjs_tags_enabled` - enable tags file auto generation. Defaults to `1`.

`g:vjs_tags_ignore` - additional paths to ignore when generating tags file. By default vjs tags all non git ignored js/jsx/mjs files. Array.

`g:vjs_tags_regenerate_at_start` - when vim starts and this is set to `0`, it will update existing tags file rather than regenerating it. Defaults to `1`.

### Example bindings

```vim script
au FileType {javascript,javascript.jsx} nnoremap <Leader>p :call VjsLintFix<cr>
au FileType {javascript,javascript.jsx} nnoremap <leader>R :call VjsListRequirers<cr>
```

## Development

Requires node.

```
git clone https://github.com/junegunn/vader.vim.git
yarn
```

### Running Tests

```
yarn test
```

### Update js dist

Extract variable feature talks to a js backend. That js is bundled, so that users don't need to `npm install`. Hence whenever plugin js is updated, the bundle needs to be rebuilt and checked in. 

```
yarn build
```
