const fs = require("fs");

const inputFile = process.argv[2]
if (!inputFile) {
  console.error('no input file specified')
  process.exit(1)
}
if (!fs.existsSync(inputFile)) {
  console.error('input file does not exist')
  process.exit(1)
}

const outputFile = process.argv[3]
if (!outputFile) {
  console.error('no output file specified')
  process.exit(1)
}

const TEX_W = 64
const TEX_H = 64
const TEX_SIZE = TEX_W * TEX_H * 2
const TEX_PAIR = TEX_SIZE * 2

const input = fs.readFileSync(inputFile);
const w = input[0]
const h = input[1]
const tblSize = w * h
let u = 0
let v = 0
let l = 0

const lut = [
  [1, -TEX_PAIR],
  [1, 0],
  [1, TEX_PAIR],
  [2, -TEX_PAIR],
  [2, 0],
  [2, TEX_PAIR],
  [3, -TEX_PAIR],
  [3, 0],
  [3, TEX_PAIR],
  [4, -TEX_PAIR],
  [4, 0],
  [4, TEX_PAIR],
  [5, -TEX_PAIR],
  [5, 0],
  [5, TEX_PAIR],
]

const buffer = Buffer.alloc(tblSize * 4 + 4)
buffer.writeUInt8(w, 0)
buffer.writeUInt8(h, 1)

for (let i = 0; i < tblSize; i++) {
  u += signedByte(input[2 + i])
  v += signedByte(input[2 + i + tblSize])
  l += signedByte(input[2 + i + tblSize * 2])

  if (l === 0) {
    // move.w d0,(a0)+, nop
    buffer.writeInt16BE(0x30c0, i * 4 + 2)
    buffer.writeInt16BE(0x4e71, i * 4 + 4)
  } else {
    let [reg, offset] = lut[l / 4 - 1]
    offset += (u + v * 64) * 2
    // move.w offset(aN),(a0)+
    buffer.writeInt16BE(0x30e8 + reg, i * 4 + 2)
    buffer.writeInt16BE(offset, i * 4 + 4)
  }
}

// rts
buffer.writeInt16BE(0x4e75, tblSize * 4 + 2)

fs.writeFileSync(outputFile, buffer)

function signedByte(v) {
  return v > 128 ? v - 256 : v
}
