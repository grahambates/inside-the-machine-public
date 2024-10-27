const fs = require('fs')
const { argv } = require("process")

const jsonFile = argv[2]
if (!jsonFile) {
  console.error('no input file')
  process.exit(1)
}

const outputFile = argv[3]
if (!outputFile) {
  console.error('no output file')
  process.exit(1)
}
const output = []

const { lines, dots, colorIndex } = JSON.parse(fs.readFileSync(jsonFile).toString())

var Random = function (_seed) {
  var me = {};

  var seed = function (s) {
    //output.push("using random seed " + s);
    var mask = 0xffffffff;
    var m_w = (123456789 + s) & mask;
    var m_z = (987654321 - s) & mask;

    return function () {
      m_z = (36969 * (m_z & 65535) + (m_z >>> 16)) & mask;
      m_w = (18000 * (m_w & 65535) + (m_w >>> 16)) & mask;

      var result = ((m_z << 16) + (m_w & 65535)) >>> 0;
      result /= 4294967296;
      return result;
    }
  }

  var rand = seed(_seed);

  me.get = function (max) {
    var max = max || 1;
    return rand() * max;
  }

  me.range = function (max) {
    var max = max || 2;
    return (rand() * max) - max / 2;
  }

  me.between = function (min, max) {
    min = min || 0;
    max = max || 1;
    return Math.round(rand() * max + min);
  }

  me.negative = function () {
    if (rand() < 0.5) return 1;
    return -1;
  }

  me.chance = function (chance) {
    return rand() < chance;
  }

  me.setSeed = function (s) {
    //output.push("using random seed " + s);
    rand = seed(s);
    //rand = function(){
    //    return 0.5;
    //}
  }

  return me;
}();

Random.setSeed(1);

output.push('Lines:')
output.push(' COUNT ' + lines.length)
for (let i in lines) {
  let line = lines[i]

  line.delay = Random.between(0, 200);
  line.speed = Random.between(1, 3);
  line.colorIndex = Random.between(0, colorIndex.length - 1);

  output.push(' LINE ' + [
    i,
    line.delay,
    line.colorIndex,
    line.start,
    line.end,
    line.speed,
    line.coordinates[0][0],
    line.coordinates[0][1],
    line.coordinates[line.coordinates.length - 1][0],
    line.coordinates[line.coordinates.length - 1][1],
  ].join(','))
}

for (let i in lines) {
  output.push('Coords' + i + ':')
  let px = -1
  let py = -1
  for (let [x, y] of lines[i].coordinates) {
    if (px > 0) {
      let dx = x - px
      let dy = y - py
      let steps = Math.max(Math.abs(dx), Math.abs(dy))
      let xs = Math.round(dx / steps) // ceil shouldn't be needed, but data has non-diagonals
      let ys = Math.round(dy / steps)
      output.push(' SECT ' + [steps, xs, ys].join(','))
    }
    px = x
    py = y
  }
  output.push(' EOL')
}

output.push('\nDots:')
output.push(' COUNT ' + dots.length)
for (let i in dots) {
  let delay = Random.between(100, 300);
  let dColorIndex = Random.between(0, colorIndex.length - 1);
  output.push(' DOT ' + [
    delay,
    dColorIndex,
    ...dots[i]
  ].join(','))
}

fs.writeFileSync(outputFile, output.join('\n'))
