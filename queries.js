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

module.exports = {
  findStatementStart,
  findVariablesDefinedWithinSelectionButUsedOutside
}
