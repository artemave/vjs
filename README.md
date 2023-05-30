# Vjs [![CircleCI](https://circleci.com/gh/artemave/vjs.svg?style=svg)](https://circleci.com/gh/artemave/vjs)

## What is this?

A Neovim plugin that adds a bunch of refactoring tools for Javascript/TypeScript. Namely:

- extract variable
- extract function/method
- extract class/function/variable declaration into a separate file
- declare undefined variable/method/function/class
- autocomplete `require`/`import` paths
- update imports on file rename/move
- turn a string into a template string once `${}` detected
- list imports for current file

For test related stuff I am using a dedicated [plugin](https://github.com/artemave/vigun).

## Installation

Requires [treesitter](https://github.com/nvim-treesitter/nvim-treesitter).

Use [a plugin manager](https://github.com/junegunn/vim-plug):

```vim script
Plug 'artemave/vjs'
```

If you don't use a plugin manager, don't forget to run `npm install` in the plugin directory.

### Example bindings

There are no default bindings. But you can use these:

```vim script
au FileType {javascript,javascript.jsx,typescript} vmap <leader>vv :VjsExtractVariable<cr>
au FileType {javascript,javascript.jsx,typescript} vmap <leader>vf :VjsExtractFunctionOrMethod<cr>
au FileType {javascript,javascript.jsx,typescript} nmap <leader>ve :VjsExtractDeclarationIntoFile<cr>
au FileType {javascript,javascript.jsx,typescript} nmap <leader>vd :VjsCreateDeclaration<cr>
au FileType {javascript,javascript.jsx,typescript} nmap <leader>vr :VjsRenameFile<cr>
au FileType {javascript,javascript.jsx,typescript} nmap <leader>vl :VjsListDependents<cr>
```

If you don't like binding explosion, you might want to consider [popup-menu.nvim](https://github.com/kamykn/popup-menu.nvim) to group commands in context menus.

### Configuration

`g:vjs_es_modules_complete` - don't strip out file extension from autocompleted modules and also show `index` modules. Defaults to `0`.

## Usage

#### Complete import/require paths

Vjs comes with an `omnifunc` for `require`/`import` path completion:

<img src="https://user-images.githubusercontent.com/23721/80413735-38752d80-88d0-11ea-8030-de1b17ee4796.gif" loading="lazy" width=550>

Set it up:

```viml
autocmd FileType {javascript,typescript} setlocal omnifunc=vjs#ModuleComplete
```

#### `:VjsRenameFile`

Rename/move file and update imports. It updates both imports in current file and all files that import current file.

<img src="https://user-images.githubusercontent.com/23721/82894765-62fbea00-9f53-11ea-8a64-d3bd123fe553.gif" loading="lazy" width=550>

It's also possible to batch rename files by calling `vjs#imports#RenameFile` directly. For example, assuming there is a bunch of `.mjs` files in quickfix window that I want to rename to `.jsx`, the following command will perform batch rename and update all the imports:

```
:cdo call vjs#imports#RenameFile(expand('%:r') . '.jsx')
```

#### `:'<,'>VjsExtractVariable`

Extracts selected code into a variable.

<img src="https://user-images.githubusercontent.com/23721/80576166-01ecff00-8a05-11ea-8826-01ae86e227e1.gif" loading="lazy" width=550>

#### `:'<,'>VjsExtractFunctionOrMethod`

Extracts selected code into a global function.

<img src="https://user-images.githubusercontent.com/23721/80576556-b38c3000-8a05-11ea-8be8-5b1b18e5ac87.gif" loading="lazy" width=550>

#### `:ExtractDeclarationIntoFile`

Extracts enclosing function/class into a separate file. Inserts import into the original file.

<img src="https://user-images.githubusercontent.com/23721/87256789-ef2b8780-c495-11ea-84ff-ed8d10fdec1f.gif" loading="lazy" width=550>

#### `:VjsCreateDeclaration`

If a reference under cursor happens to be undefined, this will insert a declaration for it. The appropriate declaration - variable, class or function - is automatically picked.

In a similar manner, if a method/property is not defined for `this` in the current scope, this will insert its declaration.

<img src="https://user-images.githubusercontent.com/23721/87256609-7b3caf80-c494-11ea-97aa-868b245dfd85.gif" loading="lazy" width=550>

#### `:VjsListDependents`

Shows list of modules that require/import current file in quickfix window.

<img src="https://user-images.githubusercontent.com/23721/80421625-0f0ece80-88dd-11ea-8057-93ff00adbf3e.gif" loading="lazy" width=550>

#### Template strings

Vjs can automatically convert normal string to template string once the string contains `${}`. To enable this:

```viml
autocmd TextChanged * if &ft =~ 'javascript\|typescript' | call luaeval("require'vjs'.to_template_string()") | endif
autocmd InsertLeave * if &ft =~ 'javascript\|typescript' | call luaeval("require'vjs'.to_template_string()") | endif
```

## Development

```
git clone https://github.com/artemave/vjs.git
cd vjs
./run_tests
```
