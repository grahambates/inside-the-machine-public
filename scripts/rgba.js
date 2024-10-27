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

const input = fs.readFileSync(inputFile);
const out = Buffer.allocUnsafe(input.length * 1.5);

let j = 0
for (let i = 0; i < input.length / 2; i++) {
  const v = input.readUInt16BE(i * 2) >> 4;
  // component per byte
  out.writeUInt8((v >> 8) * 2, j++);
  out.writeUInt8(((v >> 4) & 0xf) * 2, j++);
  out.writeUInt8((v & 0xf) * 2, j++);
}

fs.writeFileSync(outputFile, out);
