const fs = require('fs')
const PNG = require('pngjs').PNG
const { argv } = require("process")

const uvFile = argv[2]
if (!uvFile) {
  console.error('no input file')
  process.exit(1)
}
const uvPng = PNG.sync.read(fs.readFileSync(uvFile))

const outputFile = argv[3]

const uTbl = []
const vTbl = []

for (let y = 0; y < uvPng.height; y++) {
  for (let x = 0; x < uvPng.width; x++) {
    let idx = (uvPng.width * y + x) << 2;
    const blue = uvPng.data[idx + 2]
    if (blue > 128) {
      vTbl.push(128)
      uTbl.push(128)
    } else {
      vTbl.push(Math.floor(uvPng.data[idx + 1] / 4))
      uTbl.push(Math.floor(uvPng.data[idx] / 4))
    }
  }
}

const buffer = new Uint8Array(uvPng.height * uvPng.width * 2 + 2)

let i = 0;
buffer[i++] = uvPng.width
buffer[i++] = uvPng.height;

[uTbl, vTbl].forEach(row => {
  let prev = 0;
  row.forEach(v => {
    buffer[i++] = v - prev
    prev = v
  })
})

fs.writeFileSync(outputFile, buffer)
