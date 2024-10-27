const perlin = require('perlin-noise');

function formatTable(values, options = {}) {
  const opts = {
    size: "b",
    rowSize: 16,
    hex: false,
    ...options,
  };
  let output = opts.label ? opts.label + ":" : "";
  for (let i in values) {
    output += i % opts.rowSize ? "," : `\n  dc.${opts.size}  `;
    output += opts.hex ? formatHex(values[i], opts.size) : values[i];
  }
  return output;
};

const sizes = {
  b: 1,
  w: 2,
  l: 4,
};

function formatHex(value, size) {
  const l = sizes[size];
  const max = Math.pow(2, 8 * l);
  if (value < 0) {
    value = max + value;
  }
  value = value % max;
  return "$" + value.toString(16).padStart(l * 2, "0");
}

function main() {
  const values = perlin.generatePerlinNoise(1024, 1).map(v => Math.floor(v * 1024));
  console.log(formatTable(values, { size: 'w', label: 'Noise', hex: true }))
}

main();
