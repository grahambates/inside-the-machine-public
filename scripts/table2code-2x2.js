const fs = require("fs");
const yargs = require('yargs/yargs')
const { hideBin } = require('yargs/helpers')
const argv = yargs(hideBin(process.argv)).argv

const inputFile = argv._[0]
if (!inputFile) {
  console.error('no input file')
  process.exit(1)
}
if (!fs.existsSync(inputFile)) {
  console.error('input file does not exist')
  process.exit(1)
}
const outputFile = argv._[1]
if (!outputFile) {
  console.error('no output file')
  process.exit(1)
}

const TEX_W = argv.texw ?? 128
const TEX_H = argv.texh ?? 128
const SCRAMBLE_OPTS = argv.opts ?? false
const MULTI_TEX = argv.multi ?? false

const input = fs.readFileSync(inputFile);
const w = input[0]
const h = input[1]
const tblSize = w * h
let u = 0
let v = 0
let l = 0

const out = []
const indexes = []

for (let i = 0; i < tblSize; i++) {
  u += signedByte(input[2 + i])
  v += signedByte(input[2 + i + tblSize])
  if (MULTI_TEX) {
    l += signedByte(input[2 + i + tblSize * 2])
  }
  if (u === 128) {
    out.push([null, l])
  } else {
    out.push([(u + v * TEX_W) * 2, l])
  }
}
out.reverse()

const blocks = [];
for (let i = 0; i < out.length / 8; i++) {
  const idx = i * 8;
  blocks.push([out[idx], out[idx + 1], out[idx + 4], out[idx + 5]]);
  blocks.push([out[idx + 2], out[idx + 3], out[idx + 6], out[idx + 7]]);
}

const opts = {
  doubleFirst: 0,
  doubleSecond: 0,
  sequential: 0,
};

const output = []

blocks.forEach(([[a, al], [b, bl], [c, cl], [d, dl]], i) => {
  const n = 7 - (i % 8);

  let firstPairDone = false

  if (SCRAMBLE_OPTS) {
    if (d !== null && c !== null) {
      if (d === c + 1) {
        opts.sequential++;
        output.push(` move.w ${d}(a4),d${n}`);
        firstPairDone = true
      } else if (d === c) {
        opts.doubleFirst++;
        output.push(` move.w ${d}(a3),d${n}`);
        firstPairDone = true
      }
    }
  }

  if (!firstPairDone) {
    if (d === null) {
      output.push(` moveq #0,d${n}`);
    } else {
      output.push(` move.w ${d}(a${1+dl}),d${n}`);
    }
    if (c !== null) {
      output.push(` or.w ${c}(a${2+cl}),d${n}`);
    }
  }

  let secondPairDone = false

  if (SCRAMBLE_OPTS) {
    if (b !== null && a !== null) {
      if (b === a + 1) {
        opts.sequential++;
        output.push(` move.b ${b}(a4),d${n}`);
        secondPairDone = true
      } else if (b === a) {
        opts.doubleSecond++;
        output.push(` move.b ${a}(a3),d${n}`);
        secondPairDone = true
      }
    }
  }

  if (!secondPairDone) {
    if (b === null) {
      if (d !== null) {
        output.push(` clr.b d${n}`);
      }
    } else {
      output.push(` move.b ${b}(a${1+bl}),d${n}`);
    }
    if (a !== null) {
      output.push(` or.b ${a}(a${2+al}),d${n}`);
    }
  }

  if (n === 0) {
    output.push(` movem.w d0-d7,-(a0)`);
  }
});

output.push(" rts");

if (SCRAMBLE_OPTS) {
  output.push(
    Object.keys(opts)
      .map((k) => "; " + k + ": " + opts[k])
      .join("\n")
  );
}

fs.writeFileSync(outputFile, output.join('\n'))

function signedByte(v) {
  return v > 128 ? v - 256 : v
}
