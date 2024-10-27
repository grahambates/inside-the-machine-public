const fs = require('fs')
const { sin, cos, PI, round, sqrt, atan2, min, max } = Math;

const outputFile = process.argv[2]
if (!outputFile) {
  console.error('no output file specified')
  process.exit(1)
}

const TABLE_W = 80
const TABLE_H = 49
// const TABLE_W = 110
// const TABLE_H = 70

const dstWidth = TABLE_W
const dstHeight = TABLE_H
const srcWidth = 64
const srcHeight = 64

const shades = 16;
const uRept = 3;
const vScale = 2;

// https://devlog-martinsh.blogspot.com/2011/03/glsl-8x8-bayer-matrix-dithering.html
const bayer8 = [
  [0, 32, 8, 40, 2, 34, 10, 42] /* 8x8 Bayer ordered dithering  */,
  [48, 16, 56, 24, 50, 18, 58, 26] /* pattern.  Each input pixel   */,
  [12, 44, 4, 36, 14, 46, 6, 38] /* is scaled to the 0..63 range */,
  [60, 28, 52, 20, 62, 30, 54, 22] /* before looking in this table */,
  [3, 35, 11, 43, 1, 33, 9, 41] /* to determine the action.     */,
  [51, 19, 59, 27, 49, 17, 57, 25],
  [15, 47, 7, 39, 13, 45, 5, 37],
  [63, 31, 55, 23, 61, 29, 53, 21],
].map((r) => r.map((v) => (v - 32) / 32));

const uTbl = []
const vTbl = []
const shadeTbl = []

for (let j = 0; j < dstHeight; j++) {
  for (let i = 0; i < dstWidth; i++) {
    const x = -1 + (2 * i) / dstWidth;
    const y = -1 + (2 * j) / dstHeight;
    const r = sqrt(x * x + y * y);
    const a = atan2(y, x);

    const x1 = x * (dstWidth / dstHeight);
    const r1 = sqrt(x1 * x1 + y * y); // Aspect corrected radius

    let u, v, b

    //-------------------------------------------------------------------------------
    // Effect code goes here:

    // tunnel
    v = 1 / (r1 * vScale);
    u = (a * uRept) / (2 * PI);
    b = max(min(r1 / 1.3, 1), 0);
    b *= Math.abs(sin(x1 / 2))
    // b = 0
    // b = .5

    // // star
    // u = 1 / (r + 0.5 + 0.5 * sin(3 * a))
    // v = a * 2 / PI
    // //
    // // // swirl
    // u = x * cos(r1) - y * sin(r1)
    // v = y * cos(r1) + x * sin(r1)
    // //
    // // // distort
    // u = r1 * cos(a + r1)
    // v = r1 * sin(a + r1)
    // b = r1 * Math.abs(cos(a + r1 * 2))
    //

    // combo
    // v = a * 2 / PI
    // u = x * cos(r) - y * sin(r)
    //
    // v = a * 1 / PI
    // u = x * cos(r)

    //-------------------------------------------------------------------------------

    if (v > 0x8000) {
      v = 0;
    }

    u = round(srcWidth * u) % srcWidth
    v = round(srcHeight * v) % srcHeight

    if (u < 0) u += srcWidth
    if (v < 0) v += srcHeight

    uTbl.push(u)
    vTbl.push(v)

    const adjust = bayer8[i % 8][j % 8] / shades / 2;
    shadeTbl.push(quantizeBrightness(b + adjust) * 4)
  }
}

function quantizeBrightness(brightness) {
  let adjustedBrightness = (brightness * shades) - 0.5;
  return Math.max(0, Math.min(shades - 1, Math.round(adjustedBrightness)));
}

const buffer = new Uint8Array(TABLE_H * TABLE_W * 3 + 2)

let i = 0;
buffer[i++] = TABLE_W
buffer[i++] = TABLE_H;

[uTbl, vTbl, shadeTbl].forEach(row => {
  let prev = 0;
  row.forEach(v => {
    buffer[i++] = v - prev
    prev = v
  })
})

fs.writeFileSync(outputFile, buffer)
