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

  context('class method with "this" in the selected text (inside an inner function)', function() {
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

  context('class method with "this" in the selected text (inside an arrow function)', function() {
    before(function() {
      code = `
        import {foo} from 'bar'

        class Aaa {
          stuff(aa) {
            const b = a
            const n = 2

            return {
              a: () => {
                let c = this.aaa
                foo(work(c))
              }
            }
          }
        }

        function asdf() {
          const x = 5
        }

        const d = 3
      `
    })

    it('returns "classMethod"', function() {
      assert.deepEqual(determineExtractedFunctionType({ast, start_line: 11, end_line: 11}), 'classMethod')
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

  context('all together now', function() {
    before(function() {
      code = `
        class Arse {
          constructor() {
            this.aaa = 111
          }

          stuff() {
            const m = () => {
              console.log('arrow', this.aaa);
            }
            m()

            function inner() {
              return {
                aa: () => {
                  // BIND
                  console.log('inner arrow', this.aaa)
                },
                af: function() {
                  console.log('inner method', this.aaa)
                },
                aaa: 222,
                deeper: {
                  aaa: 333,
                  b() {
                    console.log('deeper method', this.aaa)
                  },
                  bb: () => {
                    // BIND
                    console.log('deeper arrow', this.aaa)

                    const n = () => {
                      // BIND
                      console.log('deeper deeper arrow', this.aaa);
                    }
                    n()
                  },
                  bbb: function() {
                    console.log('deeper method', this.aaa)
                  }
                }
              }
            }

            return inner.call(this)
          }
        }

        const a = new Arse().stuff()
        a.aa()
        a.af()
        a.deeper.b()
        a.deeper.bb()
        a.deeper.bbb()

        // arrow 111
        // inner arrow 111
        // inner method 222
        // deeper method 333
        // deeper arrow 111
        // deeper deeper arrow 111
        // deeper method 333
      `
    })

    it('returns type', function() {
      assert.deepEqual(determineExtractedFunctionType({ast, start_line: 9, end_line: 9}), 'classMethod')
      assert.deepEqual(determineExtractedFunctionType({ast, start_line: 17, end_line: 17}), 'unboundFunction')
      assert.deepEqual(determineExtractedFunctionType({ast, start_line: 20, end_line: 20}), 'objectMethod')
      assert.deepEqual(determineExtractedFunctionType({ast, start_line: 26, end_line: 26}), 'objectMethod')
      assert.deepEqual(determineExtractedFunctionType({ast, start_line: 30, end_line: 30}), 'unboundFunction')
      assert.deepEqual(determineExtractedFunctionType({ast, start_line: 34, end_line: 34}), 'unboundFunction')
      assert.deepEqual(determineExtractedFunctionType({ast, start_line: 39, end_line: 39}), 'objectMethod')
    })
  })
})
