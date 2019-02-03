const {parse} = require('@babel/parser')
const readline = require('readline')

const rl = readline.createInterface({
  input: process.stdin
})

rl.on('line', code => {
  try {
    if (isValidJs(code)) {
      console.log(true)
    } else {
      console.log(false)
    }
  } catch (e) {
    console.error(e)
  }
})

function isValidJs(code) {
  try {
    parse(code, {
      sourceType: "module",

      plugins: [
        "jsx",
        "flow"
      ]
    })
    return true
  } catch (e) {
    return false
  }
}

// prevent exit
new Promise(() => {})
