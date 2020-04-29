# Vjs [![CircleCI](https://circleci.com/gh/artemave/vjs.svg?style=svg)](https://circleci.com/gh/artemave/vjs)

## What is this?

Vim plugin that brings about a bunch of powertricks for writing Javascript:

Namely:

- autocomplete `require`/`import` paths
- list files that require/import current file
- extract variable
- extract function
- auto generating and keeping up to date `tags` file
- list Express routes

There is another plugin - [vigun](https://github.com/artemave/vigun) - for running tests from vim.

## Installation

Use [a plugin manager](https://github.com/junegunn/vim-plug):

```vim script
Plug 'artemave/vjs'
``` 

## Usage

#### Complete require paths

Vjs registers an `omnifunc` for `require`/`import` path completion - `CTRL-X CTRL-O` - which gives you this:

<img src="https://user-images.githubusercontent.com/23721/80413735-38752d80-88d0-11ea-8030-de1b17ee4796.gif" loading="lazy">

Vjs comes with no bindings, but does add the following commands:

#### `:VjsListDependents`

Shows list of modules that require/import current file in quickfix window.

![vjs_list_dependents](https://user-images.githubusercontent.com/23721/80421625-0f0ece80-88dd-11ea-8057-93ff00adbf3e.gif)

#### `:VjsListRoutes`

Shows list of express routes of current file in quickfix window.

![vjs_list_routes](https://user-images.githubusercontent.com/23721/80421959-9d835000-88dd-11ea-87ae-3f65638c7de4.gif)

#### `:'<,'>VjsExtractVariable`

Extracts selected code into a variable.

![vjs_extract_variable](https://user-images.githubusercontent.com/23721/80576166-01ecff00-8a05-11ea-8826-01ae86e227e1.gif)

#### `:'<,'>VjsExtractFunctionOrMethod`

Extracts selected code into a global function (TODO: or a method if applicable).

![vjs_extract_function](https://user-images.githubusercontent.com/23721/80576556-b38c3000-8a05-11ea-8be8-5b1b18e5ac87.gif)

### Configuration

`g:vjs_tags_enabled` - enable tags file auto generation. Defaults to `1`.

`g:vjs_tags_ignore` - additional paths to ignore when generating tags file. By default vjs tags all non git ignored js/jsx/mjs files. Array.

`g:vjs_tags_regenerate_at_start` - when vim starts and this is set to `0`, it will update existing tags file rather than regenerating it. Defaults to `1`.

### Example bindings

```vim script
au FileType {javascript,javascript.jsx} nnoremap <Leader>p :call VjsLintFix<cr>
au FileType {javascript,javascript.jsx} nnoremap <leader>R :call VjsListDependents<cr>
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
