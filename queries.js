const traverse = require('@babel/traverse').default
const t = require('@babel/types')

function findStatementStart({ast, current_line}) {
  let result = {
    line: 1, column: 0
  }

  traverse(ast, {
    Statement({node}) {
      const {loc} = node
      if (loc.start.line <= current_line && loc.end.line >= current_line) {
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
          scope.bindings[name].referencePaths.forEach(({node}) => {
            if (node.loc.start.line > end_line) {
              result[name] = kind
            }
          })
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

  traverse(ast, {
    Scope(path) {
      const loc = path.node.loc

      if (!currentScopePath) {
        currentScopePath = path
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

  for (let path = currentScopePath; path.parentPath; path = path.parentPath) {
    for (const [name, binding] of Object.entries(path.scope.bindings)) {
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

module.exports = {
  findStatementStart,
  findVariablesDefinedWithinSelectionButUsedOutside,
  findGlobalScopeStart,
  findGlobalFunctionArguments,
  determineExtractedFunctionType,
}
