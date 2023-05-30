fun! s:ImportsSearchTerm(for)
  if a:for == 'grep'
    " \x27 is ascii for single quote
    return '(require\(.*\)|^ *import  *"|^ *import  *\x27| from )'
  else
    return '\(require(.*)\|^ *import  *"\|^ *import  *\x27\| from \)'
  endif
endf

function! s:FindNodeDependencyPath(directory, dependency)
  if a:directory == '/'
    return
  endif

  let dependencyDirectory = a:directory . "/node_modules/" . a:dependency

  if isdirectory(dependencyDirectory)
    return dependencyDirectory
  else
    return s:FindNodeDependencyPath(fnamemodify(a:directory, ':h'), a:dependency)
  endif
endfunction

function! s:ModuleName(path)
  let components = split(a:path, '/')
  if a:path =~ '^@'
    return join(components[0:1], '/')
  else
    return components[0]
  endif
endfunction

function! s:ModuleMain(dirname)
  let packageFilename = a:dirname . '/package.json'

  if filereadable(packageFilename)
    let package = json_decode(readfile(packageFilename))

    if has_key(package, 'main')
      return package['main']
    endif
  endif
endfunction

function! s:ResolveMain(dirname, moduleRelativeFilename)
  if len(a:moduleRelativeFilename) > 0
    return resolve(a:dirname . a:moduleRelativeFilename)
  else
    let main = s:ModuleMain(a:dirname)

    if main isnot 0
      return resolve(a:dirname . '/' . main)
    else
      return resolve(a:dirname)
    endif
  endif
endfunction

function! vjs#imports#ResolvePackageImport(fname)
  if a:fname !~ '^\.'
    let fromFile = expand('%:p')
    let dirname = fnamemodify(fromFile, ':h')
    let moduleName = s:ModuleName(a:fname)
    let moduleRelativeFilename = a:fname[len(moduleName):-1]
    let found = s:FindNodeDependencyPath(dirname, moduleName)

    if found isnot 0
      return s:ResolveMain(found, moduleRelativeFilename)
    endif
  endif
endfunction

fun! s:PrepareDependantsList()
  let raw_results = systemlist(&grepprg . " '" . s:ImportsSearchTerm('grep'). "'")
  let all_imports = getqflist({'lines': raw_results, 'efm': &grepformat}).items

  let result_entries = []
  let current_file_full_path = expand('%:p:r')

  for require in all_imports
    let match = matchlist(require.text, "['\"]".'\(.\+\)'."['\"]")
    if len(match) > 0
      let module_path = match[1]

      let package_import = vjs#imports#ResolvePackageImport(module_path)

      if package_import isnot 0 && package_import == expand('%:p')
        call add(result_entries, require)
      else
        let module_path_with_explicit_index = ''

        if match(module_path, '\.$') != -1
          let module_path = module_path . '/index'
        elseif match(module_path, '\/$') != -1
          let module_path = module_path . 'index'
        elseif match(module_path, 'index\(\.[tj]sx\?\)\?$') == -1
          let module_path_with_explicit_index = module_path . '/index'
        endif

        if match(module_path, '^\~') != -1
          " drop leading `~/`
          let module_path = module_path[2:]
          let module_base = getcwd()
        else
          let module_base = fnamemodify(bufname(require.bufnr), ':p:h')
        endif

        let module_full_path = fnamemodify(module_base . '/' . module_path, ':p:r')
        let module_full_path_with_explicit_index = fnamemodify(module_base . '/' . module_path_with_explicit_index, ':p:r')

        if module_full_path == current_file_full_path || module_full_path_with_explicit_index == current_file_full_path
          call add(result_entries, require)
        endif
      endif
    endif
  endfor

  return result_entries
endf

fun! vjs#imports#ListDependents()
  let entries = s:PrepareDependantsList()
  call setqflist([], ' ', {'items': entries, 'title': 'Modules that import '.expand('%')})
  copen
endf

fun! vjs#imports#RenameFile(new_name = '')
  let old_file_path = expand('%')
  let old_name = expand('%:t:r')
  let current_line = line('.')
  let new_name = len(a:new_name) ? a:new_name : input('New name: ', expand('%:h') .'/', 'file')

  let full_new_name_path = fnamemodify(getcwd() . '/'. new_name, ':p')

  if !exists('g:vjs_test_env')
    if rename(expand('%:p'), full_new_name_path) != 0
      echoerr '... rename failed!'
      return
    end
  endif

  let dependants = s:PrepareDependantsList()

  let imported_module_full_path_parts = split(full_new_name_path, '/')

  for require in dependants
    let import_path_parts = []
    let fname = bufname(require.bufnr)
    let importing_module_full_path_parts = split(fnamemodify(fname, ':p'), '/')

    let import_path_parts = vjs#imports#calculateImportPathParts(importing_module_full_path_parts, imported_module_full_path_parts)

    let new_import_path_with_extension = join(import_path_parts, '/')
    let new_import_path = g:vjs_es_modules_complete ? new_import_path_with_extension : fnamemodify(new_import_path_with_extension, ':r')

    let new_text_pattern = '\(["'']\).*["'']'
    let new_text_replacement = '\1'. new_import_path .'\1'

    let new_text = substitute(require.text, new_text_pattern, new_text_replacement, '')
    let require.text = new_text

    let platform = substitute(system('uname'), '\n', '', '')
    if platform == 'Darwin'
      let cmd = "/usr/bin/sed -i '' -e "
    else
      let cmd = 'sed -i -e '
    endif

    let cmd = cmd .'"'. require.lnum .'s/'. escape(new_text_pattern, '/\"') .'/'. escape(new_text_replacement, '/\"') .'/" '. fname
    if !exists('g:vjs_test_env')
      let output = system(cmd)
      if v:shell_error
        throw output
      endif
    endif
  endfor

  if !exists('g:vjs_test_env')
    silent bwipeout!
    execute 'edit +'. current_line full_new_name_path
  endif

  call vjs#imports#UpdateCurrentFileImports(old_file_path, full_new_name_path)

  " Hack. Presence of new name indicates programmatic usage (a batch rename
  " likely) in which case we don't want to modify/open qflist
  if len(a:new_name) == 0
    call setqflist([], ' ', {'title': 'Imports updated', 'items': dependants})
    copen
  endif
endf

fun! vjs#imports#UpdateCurrentFileImports(current_file_name, new_file_name)
  let current_cursor_pos = getcurpos()

  let imported_module_base_path = fnamemodify(a:current_file_name, ':p:h')
  let importing_module_full_path_parts = split(fnamemodify(a:new_file_name, ':p'), '/')

  call cursor(1,1)

  while search(s:ImportsSearchTerm('vim'), 'Wez') > 0
    let rx = '\(["'']\)\(\.[^"'']*\)["'']'
    let match = matchlist(getline('.'), rx)
    if len(match) > 2
      let m = match[2]
      if m == '.' || m == '..'
        let m = 'index'
      endif

      let imported_module_full_path = fnamemodify(imported_module_base_path .'/'. m, ':p')
      let imported_module_full_path_parts = split(imported_module_full_path, '/')

      let import_path_parts = vjs#imports#calculateImportPathParts(importing_module_full_path_parts, imported_module_full_path_parts)

      if m == 'index'
        let import_path_parts = import_path_parts[:-2]
      end

      let result = substitute(getline('.'), rx, '\1'. join(import_path_parts, '/') .'\1', '')
      call setline('.', result)
    endif
  endwhile

  call setpos('.', current_cursor_pos)
endf

fun! vjs#imports#calculateImportPathParts(importing_module_full_path_parts, imported_module_full_path_parts)
  let max_len = max([len(a:importing_module_full_path_parts), len(a:imported_module_full_path_parts)])

  let idx = 0
  let paths_diverged = v:false
  let import_path_parts = []

  while idx < max_len
    if idx >= len(a:imported_module_full_path_parts)
      call insert(import_path_parts, '..', 0)
      let idx = idx + 1
      continue
    endif

    if idx >= len(a:importing_module_full_path_parts)
      call add(import_path_parts, a:imported_module_full_path_parts[idx])
      let idx = idx + 1
      continue
    endif

    if a:importing_module_full_path_parts[idx] != a:imported_module_full_path_parts[idx] || paths_diverged
      if paths_diverged
        call insert(import_path_parts, '..', 0)
      end
      let paths_diverged = v:true

      call add(import_path_parts, a:imported_module_full_path_parts[idx])
    endif

    let idx = idx + 1
  endwhile

  if import_path_parts[0] != '..'
    call insert(import_path_parts, '.', 0)
  endif

  return import_path_parts
endf
