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

module.exports = {
  findStatementStart
}
