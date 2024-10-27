const fs = require('fs')
const { argv } = require("process")
const { readPngFileSync, writePngFileSync } = require("node-libpng")
const { bayer8 } = require('./dither')

const R = 16
const COLS = 16

const w = R * 2
const h = R * 2 * COLS * 2

const colFile = argv[2]
if (!colFile) {
  console.error('no color file')
  process.exit(1)
}

const uvFile = argv[3]
if (!uvFile) {
  console.error('no uv file')
  process.exit(1)
}

const outputFile = argv[4]
if (!outputFile) {
  console.error('no output file')
  process.exit(1)
}

const colPng = readPngFileSync(colFile);
const uvPng = readPngFileSync(uvFile);

const tblWidth = colPng.width

const pixels = []

let i = 0
for (let j = 0; j < colPng.data.length; j++) {
  const a = uvPng.data[i++]
  const r = uvPng.data[i++]
  const g = uvPng.data[i++]
  const b = uvPng.data[i++]

  const x = j % tblWidth
  const y = Math.floor(j / tblWidth)

  const adjust = bayer8[x % 8][y % 8] / 256;

  const u = r / 255 + adjust
  const v = g / 255 + adjust


  pixels.push({
    idx: j,
    u,
    v,
    x,
    y,
    colIdx: colPng.data[j]
  })
}

const imageData = Buffer.alloc(w * h * 3);
const options = {
  width: w,
  height: h
};

i = 0
const itemSize = w * w * 3;


for (let [_, col] of colPng.palette) {
  for (let y = 0; y < w; y++) {
    for (let x = 0; x < w; x++) {
      let d = Math.max(0, R - Math.sqrt(Math.pow((x - R), 2) + Math.pow((y - R), 2))) / R
      d = Math.sin(d * Math.PI / 2)
      d = d * 1.2

      let [r, g, b] = col.map(c => fade(c, d))

      imageData[i + itemSize] = r
      imageData[i++] = r
      imageData[i + itemSize] = g
      imageData[i++] = g
      imageData[i + itemSize] = b
      imageData[i++] = b
    }
  }
  i += itemSize
}

function fade(c, d) {
  if (d <= 1) {
    return Math.round(c * d)
  } else {
    return c + (255 - c) * (d - 1)
  }
}

writePngFileSync(outputFile, imageData, options);

const origin = w * w * 2 * COLS
console.log(';origin' + origin)

for (let { u, v, colIdx } of pixels) {
  if (colIdx === 0) {
    console.log(' move.w #0,(a2)+')
  } else {
    const offset = (
      Math.round(v * w * 2) * w + // TODO: why *2 ?
      Math.round(u * w * 2) //+
      // colIdx * w * w * 2
    ) * 2 - origin
    // move.w offset(a0),(a2)+
    // use data to prevent assembler optimisation removing zero offset
    console.log(' dc.w $34e8,' + offset)
  }
}

console.log('\n')
console.log('FlipIdxs:')
pixels.filter(p => p.colIdx > 0)
  .sort((a, b) => (a.x + a.u * 50) - (b.x + b.u * 50))
  .forEach(p => console.log(' dc.w ' + p.idx * 4))
console.log(' dc.w -1')
console.log('FlipIdxsE:')
