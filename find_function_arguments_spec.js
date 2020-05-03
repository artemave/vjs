const assert = require('assert').strict
const {parse} = require('@babel/parser')
const {findGlobalFunctionArguments} = require('./queries')

describe('findGlobalFunctionArguments', function() {
  let ast, code

  beforeEach(function() {
    ast = parse(code, {sourceType: 'module'})
  })

  context('the entire current scope is selected', function() {
    before(function() {
      code = `
        import {foo} from 'bar'

        const a = 2

        function stuff(aa) {
          const b = a
          const n = 2

          for (let x of aa) {
            let c = b + n + x + a
            foo(work(c))
          }

          return c + 3
        }

        function asdf() {
          const x = 5
        }

        const d = 3
      `
    })

    it('returns line before outer function start', function() {
      assert.deepEqual(findGlobalFunctionArguments({ast, start_line: 11, end_line: 12}), ['x', 'b', 'n'])
    })
  })

  context('part of the current scope selected', function() {
    before(function() {
      code = `
        const a = 2

        function donc() {
          return 1
        }

        function getParentModuleName() {
          const caller = stack.shift()

          let path2 = caller.split(' ').pop()
          path2 = path2.replace(/^/, '')

          return path
        }
      `
    })

    it('returns line before outer function start', function() {
      assert.deepEqual(findGlobalFunctionArguments({ast, start_line: 10, end_line: 11}), ['caller'])
    })
  })

  context('part of the current scope selected', function() {
    before(function() {
      code = `
        import {foo} from 'bar'

        const aaa = {
          stuff(aa) {
            const b = a
            const n = 2

            const c = this.aaa
            foo(work(c, b, n))

            return c + 3
          }
        }
      `
    })

    it('returns line before outer function start', function() {
      assert.deepEqual(findGlobalFunctionArguments({ast, start_line: 9, end_line: 10}), ['b', 'n'])
    })
  })
})
