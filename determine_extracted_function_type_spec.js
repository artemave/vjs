const assert = require('assert').strict
const {parse} = require('@babel/parser')
const {determineExtractedFunctionType} = require('./queries')

describe('determineExtractedFunctionType', function() {
  let ast, code

  beforeEach(function() {
    ast = parse(code, {sourceType: 'module'})
  })

  context('class method with "this" in the selected text', function() {
    before(function() {
      code = `
        import {foo} from 'bar'

        class Aaa {
          stuff(aa) {
            const b = a
            const n = 2

            for (let x of aa) {
              let c = this.aaa
              foo(work(c))
            }

            return c + 3
          }
        }

        function asdf() {
          const x = 5
        }

        const d = 3
      `
    })

    it('returns "classMethod"', function() {
      assert.deepEqual(determineExtractedFunctionType({ast, start_line: 9, end_line: 10}), 'classMethod')
    })
  })

  context('class method with "this" in the selected text (wrapped in inner function)', function() {
    before(function() {
      code = `
        import {foo} from 'bar'

        class Aaa {
          stuff(aa) {
            const b = a
            const n = 2

            function opi() {
              let c = this.aaa
              foo(work(c))
            }

            return c + 3
          }
        }

        function asdf() {
          const x = 5
        }

        const d = 3
      `
    })

    it('returns "unboundFunction"', function() {
      assert.deepEqual(determineExtractedFunctionType({ast, start_line: 9, end_line: 10}), 'unboundFunction')
    })
  })

  context('object method with "this" in the selected text', function() {
    before(function() {
      code = `
        import {foo} from 'bar'

        const bbbn = {
          stuff(aa) {
            const b = a
            const n = 2

            for (let x of aa) {
              let c = this.aaa
              foo(work(c))
            }

            return c + 3
          }
        }

        function asdf() {
          const x = 5
        }

        const d = 3
      `
    })

    it('returns "objectMethod"', function() {
      assert.deepEqual(determineExtractedFunctionType({ast, start_line: 9, end_line: 10}), 'objectMethod')
    })
  })

  context('object function property with "this" in the selected text', function() {
    before(function() {
      code = `
        import {foo} from 'bar'

        const bbbn = {
          stuff: function(aa) {
            const b = a
            const n = 2

            for (let x of aa) {
              let c = this.aaa
              foo(work(c))
            }

            return c + 3
          }
        }

        function asdf() {
          const x = 5
        }

        const d = 3
      `
    })

    it('returns "objectMethod"', function() {
      assert.deepEqual(determineExtractedFunctionType({ast, start_line: 9, end_line: 10}), 'objectMethod')
    })
  })

  context('class method without "this" in the selected text', function() {
    before(function() {
      code = `
        import {foo} from 'bar'

        class Aaa {
          stuff(aa) {
            const b = a
            const n = 2

            for (let x of aa) {
              let c = b + n + x + a
              foo(work(c))
            }

            return c + 3
          }
        }

        function asdf() {
          const x = 5
        }

        const d = 3
      `
    })

    it('returns "function"', function() {
      assert.deepEqual(determineExtractedFunctionType({ast, start_line: 9, end_line: 10}), 'function')
    })
  })

  context('global function', function() {
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

    it('returns "function"', function() {
      assert.deepEqual(determineExtractedFunctionType({ast, start_line: 10, end_line: 11}), 'function')
    })
  })
})
