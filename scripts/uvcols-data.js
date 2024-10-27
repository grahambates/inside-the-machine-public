const fs = require('fs')
const { argv } = require("process")
const { readPngFileSync, writePngFileSync } = require("node-libpng")
const { bayer8 } = require('./dither')
const { scrambleRgb } = require('./scramble')

const COLS = 16 - 1
const TEX_W = 64
const TEX_H = 48
const TEX_PAIR = TEX_W * TEX_H * 4

const texSize = TEX_W * TEX_H

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

const codeOutputFile = argv[4]
if (!codeOutputFile) {
  console.error('no code output file')
  process.exit(1)
}

const rampOutputFile = argv[5]
if (!rampOutputFile) {
  console.error('no ramp output file')
  process.exit(1)
}

const flipOutputFile = argv[6]
if (!flipOutputFile) {
  console.error('no flip output file')
  process.exit(1)
}

const colPng = readPngFileSync(colFile);
const uvPng = readPngFileSync(uvFile);

const tblWidth = colPng.width

// Collect all data for each pixel
const pixels = []

let uvIdx = 0
for (let i = 0; i < colPng.data.length; i++) {
  const a = uvPng.data[uvIdx++] // not used
  const r = uvPng.data[uvIdx++] // red = U
  const g = uvPng.data[uvIdx++] // green = V
  const b = uvPng.data[uvIdx++] // not used

  const x = i % tblWidth
  const y = Math.floor(i / tblWidth)

  // Dither UV values?
  // const adjust = bayer8[x % 8][y % 8] / 500;
  const adjust = 0

  const u = r / 255 + adjust
  const v = g / 255 + adjust


  pixels.push({
    idx: i,
    // Float values
    u, v,
    // Texture word offsets from UVs
    uOffset: Math.round(u * TEX_W * 2),
    vOffset: Math.round(v * TEX_H * 2),
    // Pixel coords
    x, y,
    // Colour - *4 for LUT offset
    colIdx: colPng.data[i] * 4
  })
}

// Texture data buffer
const bufferW = TEX_W
const bufferH = TEX_H * COLS * 2 // tex pair per colour
const bufferSize = bufferW * bufferH

const R = TEX_W / 2

// Generate ramps
const rampWidth = 32
const rampData = Buffer.alloc(
  (COLS) * rampWidth * 2 +
  TEX_W * TEX_H
)
let idx = 0
for (let [y, col] of colPng.palette) {
  if (!y) continue // skip colour 0
  for (let x = 0; x < rampWidth; x++) {
    const d = 1 / rampWidth * x
    const val = colVal(col, d)
    rampData.writeUInt16BE(val, (idx++) * 2)
  }
}

// Generate gradient offsets
for (let y = 0; y < TEX_H / 2; y++) {
  for (let x = 0; x < TEX_W; x++) {
    let d = Math.min(1, Math.max(0,
      R - Math.sqrt(Math.pow((x - TEX_W / 2), 2) + Math.pow((y - TEX_H / 2), 2))) / (TEX_H / 2)
    )
    rampData.writeUInt16BE(Math.floor(d * (rampWidth - 1)) * 2, (idx++) * 2)
  }
}

fs.writeFileSync(rampOutputFile, rampData)

function colVal(col, d) {
  // Control curve
  // d = Math.sin(d * Math.PI / 2) // sin curve
  // d = d * d * (3.0 - 2.0 * d) // smooth step
  // d = (d * d * d * (d * (6.0 * d - 15.0) + 10.0))// Smoother step
  // d = Math.pow(d,.8)*.8+.4
  d += .3

  let b = clamp(col[2] * d)
  d = d * 1.2 - .2
  let r = clamp(col[0] * d)
  let g = clamp(col[1] * d)

  return scrambleRgb(r, g, b)
}

function clamp(v) {
  return Math.min(255, Math.max(0, v))
}

const codeBuffer = Buffer.alloc(pixels.length * 4 + 6)
let c = 0
codeBuffer.writeUInt16BE(colPng.width, (c++) * 2)
codeBuffer.writeUInt16BE(colPng.height, (c++) * 2)

const colorLut = [
  [0x30e8 + 1, -TEX_PAIR * 2],
  [0x30e8 + 1, -TEX_PAIR],
  [0x30e8 + 1, 0],
  [0x30e8 + 1, TEX_PAIR],
  [0x30e8 + 1, TEX_PAIR * 2],
  [0x30e8 + 2, -TEX_PAIR * 2],
  [0x30e8 + 2, -TEX_PAIR],
  [0x30e8 + 2, 0],
  [0x30e8 + 2, TEX_PAIR],
  [0x30e8 + 2, TEX_PAIR * 2],
  [0x30e8 + 3, -TEX_PAIR * 2],
  [0x30e8 + 3, -TEX_PAIR],
  [0x30e8 + 3, 0],
  [0x30e8 + 3, TEX_PAIR],
  [0x30e8 + 3, TEX_PAIR * 2],
]


for (let { uOffset, vOffset, colIdx } of pixels) {
  if (colIdx > 0) {
    // instruction including source reg and initial offset looked up for colour
    let [regInst, offset] = colorLut[(colIdx) / 4 - 1]
    offset += (uOffset + vOffset * TEX_W) * 2
    codeBuffer.writeUInt16BE(regInst, (c++) * 2)
    codeBuffer.writeInt16BE(offset, (c++) * 2)
  } else {
    // special case for shade zero
    // needs to be same length as move for panning to work
    // $30fc0000 move.w #0,(a0)+
    codeBuffer.writeUInt16BE(0x30fc, (c++) * 2)
    codeBuffer.writeUInt16BE(0, (c++) * 2)
  }
}
// rts
codeBuffer.writeUInt16BE(0x4e75, (c++) * 2)

fs.writeFileSync(codeOutputFile, codeBuffer)

// Flip indexes

const flipIndexes = pixels.filter(p => p.colIdx > 0)
  .sort((a, b) => (a.x + a.u * 50) - (b.x + b.u * 50))
  .map(p => p.idx)
flipIndexes.push(0xffff)

i = 0
const flipBuffer = Buffer.alloc(flipIndexes.length * 2);
flipIndexes.forEach(v => {
  flipBuffer.writeUInt16BE(v, i * 2)
  i++
})

fs.writeFileSync(flipOutputFile, flipBuffer)
