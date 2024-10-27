const fs = require('fs')
const PNG = require('pngjs').PNG
const { argv } = require("process")

const preview = argv[2]
if (!preview) {
  console.error('no input file')
  process.exit(1)
}
const outfile = argv[3]
if (!outfile) {
  console.error('no output file')
  process.exit(1)
}

const png = PNG.sync.read(fs.readFileSync(preview))
const maxX = argv[4] ?
  Number(argv[4]) : png.width - 320

const table = Buffer.alloc(maxX * png.height * 2);
let i = 0

for (let x = 0; x < maxX; x++) {
  for (let y = 0; y < png.height; y++) {
    let idx = (png.width * y + x) << 2;
    let r = png.data[idx] / 17
    let g = png.data[idx + 1] / 17
    let b = png.data[idx + 2] / 17

    let rgb = (r << 8) + (g << 4) + b
    table.writeUInt16BE(rgb, i * 2)
    i++
  }
}

fs.writeFileSync(outfile, table)
