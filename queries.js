const traverse = require('@babel/traverse').default

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
  const result = []

  traverse(ast, {
    VariableDeclaration({node, scope}) {
      const {loc, declarations, kind} = node

      if (loc.start.line >= start_line && loc.end.line <= end_line) {
        const names = declarations.map(({id}) => id.name)

        names.forEach((name) => {
          scope.bindings[name].referencePaths.forEach(({node}) => {
            if (node.loc.start.line > end_line) {
              result.push({kind, name})
            }
          })
        })
      }
    }
  })

  return result
}

function findGlobalFunctionStart({ast, current_line}) {
  let result = findStatementStart({ast, current_line})

  traverse(ast, {
    FunctionDeclaration({node}) {
      const {loc} = node
      if (loc.start.line <= current_line && loc.end.line >= current_line) {
        if (loc.start.line < result.line) {
          result = loc.start
        }
      }
    }
  })

  return result
}

function findFunctionArguments({ast, start_line, end_line}) {
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

module.exports = {
  findStatementStart,
  findVariablesDefinedWithinSelectionButUsedOutside,
  findGlobalFunctionStart,
  findFunctionArguments,
}
