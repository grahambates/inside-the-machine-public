const fs = require('fs')
const { scrambleRgb } = require('./scramble')
const { argv } = require("process")
const PNG = require('pngjs').PNG

const inputFile = argv[2]
if (!inputFile) {
  console.error('no input file')
  process.exit(1)
}

const dataOutputFile = argv[3]
if (!dataOutputFile) {
  console.error('no output file')
  process.exit(1)
}

const png = PNG.sync.read(fs.readFileSync(inputFile))
let i = 0

const scrambledData = Buffer.alloc(png.width * png.height * 2);

for (let y = 0; y < png.height; y++) {
  for (let x = 0; x < png.width; x++) {
    let idx = (png.width * y + x) << 2;
    const r = png.data[idx]
    const g = png.data[idx + 1]
    const b = png.data[idx + 2]
    const v = scrambleRgb(r, g, b)
    scrambledData.writeUInt16BE(v, i * 2)
    i++
  }
}

fs.writeFileSync(dataOutputFile, scrambledData)
