// Changes:
// speed is number of dots to draw per frame
// 4 colors, so highlight is its own bitplane
//
// Query:
// non-diagonals

// Implementation:
// Store ptr to current section per line
// Sore orignal too
// Highlight head (draw) and tail (clear) position, head can be same as initial draw ptr
// Pre multiply Y offsets by BW
//
// BOBs for dots?

let lines = [
  { coordinates: [[62, 40], [90, 40], [101, 29], [119, 29], [123, 25], [123, 6]], start: 1, end: 0, speed: 3 },
  { coordinates: [[62, 44], [90, 44], [101, 33], [122, 33], [128, 27], [128, 6]], start: 1, end: 0, speed: 2 },
  { coordinates: [[62, 48], [90, 48], [101, 37], [126, 37], [135, 28], [135, 6]], start: 1, end: 0, speed: 3 },
  { coordinates: [[73, 17], [82, 8], [104, 8]], start: 1, end: 1, speed: 3 },
  { coordinates: [[89, 30], [94, 30], [99, 25], [114, 25], [119, 20], [119, 9], [114, 9], [107, 16], [82, 16], [74, 24], [74, 29], [70, 33], [61, 33], [61, 26], [65, 22], [72, 22], [82, 12], [104, 12]], start: 1, end: 1, speed: 1 },
  { coordinates: [[84, 34], [84, 26], [88, 22], [95, 22]], start: 1, end: 1, speed: 2 },
  { coordinates: [[98, 46], [103, 41], [129, 41], [164, 6]], start: 1, end: 3, speed: 3 },
  { coordinates: [[62, 52], [139, 52], [147, 44], [152, 44]], start: 1, end: 1, speed: 4 },
  { coordinates: [[62, 56], [86, 56], [92, 62]], start: 1, end: 1, speed: 2 },
  { coordinates: [[95, 59], [91, 55], [123, 55], [125, 57]], start: 1, end: 1, speed: 2 },
  { coordinates: [[103, 60], [134, 60], [147, 47]], start: 1, end: 1, speed: 4 },
  { coordinates: [[62, 60], [67, 60]], start: 1, end: 1, speed: 1 },
  { coordinates: [[62, 64], [70, 64], [74, 60], [84, 60]], start: 1, end: 1, speed: 3 },
  { coordinates: [[81, 64], [105, 64], [109, 68], [156, 68], [165, 59], [180, 59], [187, 52]], start: 1, end: 2, speed: 4 },
  { coordinates: [[118, 64], [143, 64], [166, 41], [222, 41]], start: 1, end: 1, speed: 3, text: 1 },
  { coordinates: [[157, 37], [222, 37]], start: 1, end: 1, speed: 2 },
  { coordinates: [[62, 68], [98, 68]], start: 1, end: 1, speed: 3 },
  { coordinates: [[67, 75], [72, 71], [158, 71], [166, 63], [174, 63]], start: 2, end: 2, speed: 2 },
  { coordinates: [[75, 76], [78, 73], [161, 73], [166, 68], [180, 68], [187, 61]], start: 1, end: 2, speed: 3 },
  { coordinates: [[78, 81], [93, 81], [96, 78], [241, 78]], start: 1, end: 1, speed: 1 },
  { coordinates: [[86, 78], [92, 78], [94, 76], [165, 76], [169, 72]], start: 1, end: 1, speed: 4 },
  { coordinates: [[80, 84], [97, 84], [100, 82], [238, 82]], start: 1, end: 1, speed: 2, text: 2 },
  { coordinates: [[99, 87], [102, 87], [105, 84], [112, 84], [116, 88], [166, 88], [168, 86], [235, 86]], start: 1, end: 1, speed: 3 },
  { coordinates: [[82, 87], [94, 87]], start: 1, end: 0, speed: 3 },
  { coordinates: [[155, 61], [163, 53], [181, 53]], start: 1, end: 1, speed: 3 },
  { coordinates: [[74, 96], [79, 91], [95, 91], [97, 93], [102, 93], [104, 91]], start: 1, end: 0, speed: 4 },
  { coordinates: [[110, 92], [169, 92], [171, 90], [231, 90]], start: 2, end: 1, speed: 3 },
  { coordinates: [[79, 97], [83, 93], [88, 93], [91, 96], [115, 96], [117, 94]], start: 1, end: 1, speed: 3 },
  { coordinates: [[85, 98], [101, 98], [105, 102], [125, 102], [133, 94], [202, 94], [205, 97]], start: 1, end: 1, speed: 4 },
  { coordinates: [[90, 103], [92, 101], [96, 101], [102, 107], [135, 107], [146, 96], [189, 96], [197, 104]], start: 1, end: 1, speed: 3 },
  { coordinates: [[144, 105], [151, 105], [156, 100]], start: 1, end: 1, speed: 3 },
  { coordinates: [[95, 108], [99, 112], [122, 112]], start: 1, end: 1, speed: 2 },
  { coordinates: [[86, 110], [93, 117], [103, 117], [108, 122], [142, 122], [168, 96]], start: 1, end: 0, speed: 3 },
  { coordinates: [[84, 113], [91, 120], [102, 120], [106, 124], [144, 124], [168, 100], [182, 100]], start: 1, end: 2, speed: 1 },
  { coordinates: [[82, 116], [89, 123], [100, 123], [103, 126], [188, 126]], start: 1, end: 2, speed: 4 },
  { coordinates: [[109, 117], [118, 117]], start: 1, end: 1, speed: 2 },
  { coordinates: [[97, 124], [104, 131], [115, 131], [117, 132], [222, 132]], start: 0, end: 1, speed: 2, text: 3 },
  { coordinates: [[114, 134], [209, 134]], start: 1, end: 0, speed: 2 },
  { coordinates: [[94, 130], [98, 130], [102, 134], [105, 134], [108, 137], [138, 137]], start: 1, end: 1, speed: 1 },
  { coordinates: [[108, 141], [142, 141], [146, 137]], start: 1, end: 1, speed: 3 },
  { coordinates: [[62, 83], [62, 94], [65, 97], [65, 109], [75, 119], [80, 119], [90, 129], [90, 137], [94, 141]], start: 1, end: 1, speed: 2 },
  { coordinates: [[63, 102], [63, 113], [66, 113], [76, 123], [80, 123], [88, 131], [88, 142], [91, 145], [158, 145], [162, 141]], start: 1, end: 2, speed: 1 },
  { coordinates: [[59, 100], [59, 104], [61, 106], [61, 115], [65, 115], [85, 135], [85, 145], [89, 149], [187, 149], [191, 153]], start: 1, end: 0, speed: 3 },
  { coordinates: [[65, 85], [65, 93], [67, 96], [67, 108], [75, 116]], start: 1, end: 1, speed: 3 },
  { coordinates: [[70, 101], [70, 107], [77, 114]], start: 1, end: 1, speed: 3 },
  { coordinates: [[59, 106], [59, 117], [77, 135], [77, 144], [79, 146]], start: 1, end: 1, speed: 4 },
  { coordinates: [[62, 115], [80, 133], [80, 140], [81, 142]], start: 0, end: 1, speed: 2 },
  { coordinates: [[56, 110], [56, 118], [74, 136], [74, 142], [72, 144], [72, 148], [77, 153], [83, 153], [89, 159], [160, 159], [165, 164]], start: 1, end: 1, speed: 3 },
  { coordinates: [[76, 147], [80, 151], [86, 151], [91, 156], [172, 156], [176, 160]], start: 1, end: 2, speed: 2 },
  { coordinates: [[54, 114], [54, 120], [62, 128], [62, 143]], start: 1, end: 1, speed: 1 },
  { coordinates: [[47, 124], [50, 121], [55, 126], [55, 132]], start: 1, end: 1, speed: 4 },
  { coordinates: [[71, 153], [77, 159], [82, 159], [88, 165], [146, 165], [150, 169]], start: 1, end: 1, speed: 3 },
  { coordinates: [[155, 160], [164, 169], [194, 169]], start: 0, end: 1, speed: 1 },
  { coordinates: [[70, 156], [77, 163], [81, 163], [88, 170], [95, 170]], start: 1, end: 2, speed: 1 },
  { coordinates: [[109, 169], [136, 169], [140, 173], [185, 173], [201, 189], [210, 189]], start: 1, end: 1, speed: 2 },
  { coordinates: [[70, 160], [80, 170], [80, 173], [83, 176], [106, 176]], start: 1, end: 1, speed: 1 },
  { coordinates: [[122, 176], [184, 176], [201, 193], [214, 193]], start: 1, end: 1, speed: 2 },
  { coordinates: [[70, 167], [82, 179], [183, 179], [202, 198], [219, 198]], start: 1, end: 1, speed: 2, text: 4 },
  { coordinates: [[128, 184], [182, 184], [200, 202], [210, 202]], start: 1, end: 1, speed: 4 },
  { coordinates: [[122, 187], [168, 187], [173, 192]], start: 1, end: 1, speed: 2 },
  { coordinates: [[78, 183], [108, 183], [112, 187]], start: 1, end: 1, speed: 2 },
  { coordinates: [[71, 173], [71, 178], [73, 180], [73, 186], [97, 186], [101, 190], [160, 190], [163, 193]], start: 0, end: 1, speed: 4 },
  { coordinates: [[69, 174], [69, 181], [71, 183], [71, 189], [81, 189], [85, 193], [89, 193], [93, 189]], start: 0, end: 1, speed: 2 },
  { coordinates: [[68, 191], [80, 191], [86, 197], [89, 197], [94, 192], [151, 192], [154, 195]], start: 1, end: 1, speed: 4 },
  { coordinates: [[67, 194], [79, 194], [84, 199], [93, 199], [95, 197], [147, 197], [149, 195]], start: 1, end: 1, speed: 4 },
  { coordinates: [[65, 197], [76, 197], [80, 201], [156, 201], [161, 196], [175, 196], [181, 202], [181, 209]], start: 1, end: 1, speed: 2 },
  { coordinates: [[64, 200], [75, 200], [80, 207], [80, 212]], start: 1, end: 1, speed: 3 },
  { coordinates: [[73, 209], [62, 209], [60, 207], [60, 204], [75, 204], [78, 207], [78, 212], [76, 214], [69, 214], [66, 211], [63, 211], [63, 214], [66, 214], [69, 217], [82, 217], [94, 205], [146, 205], [162, 221], [162, 234], [168, 240]], start: 1, end: 0, speed: 2 },
  { coordinates: [[96, 209], [122, 209], [127, 214], [127, 218]], start: 1, end: 1, speed: 2 },
  { coordinates: [[132, 209], [132, 223], [135, 226]], start: 1, end: 1, speed: 4 },
  { coordinates: [[138, 209], [138, 233], [143, 238]], start: 1, end: 1, speed: 2 },
  { coordinates: [[86, 207], [90, 203], [164, 203], [168, 199]], start: 1, end: 1, speed: 2 },
  { coordinates: [[51, 130], [51, 143], [55, 147], [55, 173], [58, 173], [58, 160], [63, 165], [63, 174], [66, 177], [66, 187]], start: 1, end: 1, speed: 1 },
  { coordinates: [[51, 162], [51, 172], [53, 172], [53, 159]], start: 1, end: 0, speed: 2 },
  { coordinates: [[40, 139], [40, 146], [43, 149], [43, 137], [45, 135], [42, 132], [42, 129], [43, 127]], start: 2, end: 1, speed: 1 },
  { coordinates: [[47, 131], [49, 133], [49, 138], [46, 141], [46, 148], [48, 150]], start: 1, end: 1, speed: 4 },
  { coordinates: [[59, 124], [59, 153], [66, 146], [66, 137]], start: 0, end: 2, speed: 3 },
  { coordinates: [[56, 179], [60, 179], [63, 182], [63, 194]], start: 2, end: 0, speed: 2 },
  { coordinates: [[61, 198], [61, 188], [57, 184], [58, 182]], start: 0, end: 1, speed: 3 },
  { coordinates: [[145, 233], [145, 228], [142, 225], [142, 216], [145, 213], [148, 213], [157, 222]], start: 1, end: 1, speed: 4 }
];

let dots = [[58, 40], [58, 44], [58, 48], [58, 52], [58, 56], [58, 60], [58, 64], [58, 68], [58, 72], [54, 60], [54, 64], [54, 68], [54, 72], [54, 76], [54, 80], [57, 82], [57, 86], [57, 90], [60, 92], [60, 96], [57, 98], [40, 134], [71, 80], [75, 80], [69, 83], [73, 83], [71, 86], [75, 86], [79, 100], [79, 103], [82, 99], [82, 102], [83, 110], [123, 96], [127, 96], [112, 19], [71, 27], [55, 138], [70, 142], [70, 146], [70, 150], [67, 150], [64, 152], [62, 155], [59, 157], [62, 159], [65, 157], [65, 161], [68, 163], [67, 154], [68, 169], [67, 166]];

// override with more dim colors
let colorIndex = [
  {
    colors: ["#b29973"],
    targets: ["#8c895e", "#b4957a", "#5b4534", "#a19576", "#616264"],
    steps: 50
  },
  {
    colors: ["#c7aa7f"],
    targets: ["#4f5642", "#98633f", "#a4968c", "#7e6f6d", "#686e72"],
    steps: 40
  },
  {
    colors: ["#be9a7a"],
    targets: ["#b99969", "#8d684c", "#a69a7c", "#545239", "#858585"],
    steps: 30
  },
  // {
  //   colors: ["#b0917c"],
  //   targets: ["#805b3c", "#6b625d", "#544e42", "#757349", "#595d6e"],
  //   steps: 60
  // },
  // {
  //   index: 0, colors: ["#a2977a"],
  //   targets: ["#4d5259", "#5d4737", "#b29174", "#838157", "#737373"],
  //   steps: 45
  // },
]

var Random = function (_seed) {
  var me = {};

  var seed = function (s) {
    //console.log("using random seed " + s);
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
    //console.log("using random seed " + s);
    rand = seed(s);
    //rand = function(){
    //    return 0.5;
    //}
  }

  return me;
}();

Random.setSeed(1);

console.log('Lines:')
console.log(' COUNT ' + lines.length)
for (let i in lines) {
  let line = lines[i]

  line.delay = Random.between(0, 200);
  line.speed = Random.between(1, 3);
  line.colorIndex = Random.between(0, colorIndex.length - 1);

  console.log(' LINE ' + [
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
  console.log('Coords' + i + ':')
  let px = -1
  let py = -1
  for (let [x, y] of lines[i].coordinates) {
    if (px > 0) {
      let dx = x - px
      let dy = y - py
      let steps = Math.max(Math.abs(dx), Math.abs(dy))
      let xs = Math.round(dx / steps) // ceil shouldn't be needed, but data has non-diagonals
      let ys = Math.round(dy / steps)
      console.log(' SECT ' + [steps, xs, ys].join(','))
    }
    px = x
    py = y
  }
  console.log(' EOL')
}

console.log('\nDots:')
console.log(' COUNT ' + dots.length)
for (let i in dots) {
  let delay = Random.between(100, 300);
  let dColorIndex = Random.between(0, colorIndex.length - 1);
  console.log(' DOT ' + [
    delay,
    dColorIndex,
    ...dots[i]
  ].join(','))
}
