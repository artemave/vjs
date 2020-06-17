const traverse = require('@babel/traverse').default
const t = require('@babel/types')

function findStatementStart({ast, current_line}) {
  let result = {
    line: 1, column: 0
  }

  traverse(ast, {
    Statement(path) {
      const {loc} = path.node
      if (loc.start.line <= current_line && loc.end.line >= current_line) {
        if (t.isFunctionExpression(path.parent) || t.isArrowFunctionExpression(path.parent)) {
          return
        }
        if (result.line < loc.start.line) {
          result = loc.start
        }
      }
    }
  })

  return result
}

function findVariablesDefinedWithinSelectionButUsedOutside({ast, start_line, end_line}) {
  const result = {}

  traverse(ast, {
    VariableDeclaration({node, scope}) {
      const {loc, declarations, kind} = node

      if (loc.start.line >= start_line && loc.end.line <= end_line) {
        const names = declarations.map(({id}) => id.name)

        names.forEach((name) => {
          for (let s = scope; s; s = s.parent) {
            if (!result[name] && s.bindings[name]) {
              s.bindings[name].referencePaths.forEach(({node}) => {
                if (node.loc.start.line > end_line) {
                  result[name] = kind
                }
              })
            }
          }
        })
      }
    }
  })

  return Object.entries(result).map(([name, kind]) => {
    return { name, kind }
  })
}

function findGlobalScopeStart({ast, current_line}) {
  let result = {
    line: 1, column: 0
  }

  traverse(ast, {
    Statement(path) {
      const {loc} = path.node

      if (loc.start.line <= current_line && loc.end.line >= current_line) {
        result = {
          line: loc.start.line,
          column: loc.start.column
        }
        path.stop()
      }
    }
  })

  return result
}

function findGlobalFunctionArguments({ast, start_line, end_line}) {
  const result = []
  let currentScopePath
  let globalScope

  traverse(ast, {
    Scope(path) {
      const loc = path.node.loc

      if (!currentScopePath) {
        currentScopePath = path
        globalScope = path.scope
      } else {
        if (start_line >= loc.start.line && end_line <= loc.end.line) {
          const currentScopePathLoc = currentScopePath.node.loc

          if (loc.start.line >= currentScopePathLoc.start.line && loc.end.line <= currentScopePathLoc.end.line) {
            currentScopePath = path
          }
        }
      }
    }
  })

  const isGlobalBinding = (binding) => {
    return Object.values(globalScope.bindings).find(b => b === binding)
  }

  for (let path = currentScopePath; path.parentPath; path = path.parentPath) {
    for (const [name, binding] of Object.entries(path.scope.bindings)) {
      if (isGlobalBinding(binding)) {
        continue
      }

      const bindingLoc = binding.identifier.loc
      if (bindingLoc.start.line >= start_line && bindingLoc.start.line <= end_line) {
        continue
      }

      for (const referencePath of binding.referencePaths) {
        const loc = referencePath.node.loc

        if (loc.start.line >= start_line && loc.end.line <= end_line) {
          result.push(name)
        }
      }
    }
  }

  return [...new Set(result)]
}

function determineExtractedFunctionType({ast, start_line, end_line}) {
  let thisPath

  traverse(ast, {
    ThisExpression(path) {
      const {start, end} = path.node.loc
      if (start_line <= start.line && end.line <= end_line) {
        thisPath = path
        path.stop()
      }
    },
  })

  if (!thisPath) {
    return 'function'
  }

  for (let path = thisPath.parentPath; path.parentPath; path = path.parentPath) {
    if (t.isObjectMethod(path.node)) {
      return 'objectMethod'
    } else if (t.isClassMethod(path.node)) {
      return 'classMethod'
    } else if (t.isFunctionDeclaration(path.node)) {
      return 'unboundFunction'
    } else if (t.isFunctionExpression(path.node)) {
      if (path.parent.type === 'ObjectProperty') {
        return 'objectMethod'
      } else {
        return 'unboundFunction'
      }
    }
  }

  throw 'Could not determine scope for "this"'
}

function findMethodScopeStart({ast, current_line}) {
  let result = {
    line: 1, column: 0
  }

  const handler = (path) => {
    const {loc} = path.node

    if (loc.start.line <= current_line && loc.end.line >= current_line) {
      result = {
        line: loc.start.line,
        column: loc.start.column
      }
      path.stop()
    }
  }

  traverse(ast, {
    ClassMethod: handler,
    ObjectMethod: handler,
    FunctionExpression(path) {
      const {loc} = path.node

      if (path.parent.type === 'ObjectProperty' && loc.start.line <= current_line && loc.end.line >= current_line) {
        result = {
          line: path.parent.loc.start.line,
          column: path.parent.loc.start.column
        }
        path.stop()
      }
    }
  })

  return result
}

function findEnclosingDeclaration({ast, current_line}) {
  let result

  traverse(ast, {
    Declaration({node}) {
      const {loc} = node

      if (t.isFunctionDeclaration(node) || t.isVariableDeclaration(node) || t.isClassDeclaration(node)) {
        let name

        if (t.isVariableDeclaration(node)) {
          name = node.declarations[0].id.name
        } else if (node.id) {
          name = node.id.name
        } else {
          return
        }

        if (loc.start.line <= current_line && loc.end.line >= current_line) {
          if (!result || result.start_line < loc.start.line) {
            result = {
              name,
              start_line: loc.start.line,
              end_line: loc.end.line,
            }
          }
        }
      }
    }
  })
  return result
}

function isCommonJsDeclaration(node) {
  if (t.isVariableDeclaration(node)) {
    return node.declarations[0].init.callee.name === 'require'
  }
}

function findReferencedImports({ast, start_line, end_line}) {
  const result = []

  traverse(ast, {
    Declaration({node}) {
      if (!t.isImportDeclaration(node) && !isCommonJsDeclaration(node)) {
        return
      }
      const {loc} = node
    }
  })

  return result
}

module.exports = {
  findStatementStart,
  findVariablesDefinedWithinSelectionButUsedOutside,
  findGlobalScopeStart,
  findGlobalFunctionArguments,
  determineExtractedFunctionType,
  findMethodScopeStart,
  findEnclosingDeclaration,
  findReferencedImports,
}
