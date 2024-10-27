const fs = require('fs')
const PNG = require('pngjs').PNG
const { argv } = require("process")
const { bayer8 } = require('./dither')

const uvFile = argv[2]
if (!uvFile) {
  console.error('no input file')
  process.exit(1)
}
const uvPng = PNG.sync.read(fs.readFileSync(uvFile))

let outputFile, shadePng
if (argv[4]) {
  shadePng = PNG.sync.read(fs.readFileSync(argv[3]))
  outputFile = argv[4]
} else {
  outputFile = argv[3]
}

const shades = 15;

function quantizeBrightness(brightness) {
  let adjustedBrightness = (brightness * shades) - 0.5;
  return Math.max(0, Math.min(shades - 1, Math.round(adjustedBrightness)));
}

const uTbl = []
const vTbl = []
const shadeTbl = []

for (let y = 0; y < uvPng.height; y++) {
  for (let x = 0; x < uvPng.width; x++) {
    let idx = (uvPng.width * y + x) << 2;
    vTbl.push(Math.round(uvPng.data[idx] / 4))
    uTbl.push(64 - Math.round(uvPng.data[idx + 1] / 4))
    const adjust = bayer8[x % 8][y % 8] / shades / 4;
    if (shadePng) {
      shadeTbl.push(quantizeBrightness(shadePng.data[idx + 2] / 255 + adjust) * 4)
    } else {
      shadeTbl.push(7 * 4)
    }
  }
}

const buffer = new Uint8Array(uvPng.height * uvPng.width * 3 + 2)

let i = 0;
buffer[i++] = uvPng.width
buffer[i++] = uvPng.height;

[uTbl, vTbl, shadeTbl].forEach(row => {
  let prev = 0;
  row.forEach(v => {
    buffer[i++] = v - prev
    prev = v
  })
})

fs.writeFileSync(outputFile, buffer)
