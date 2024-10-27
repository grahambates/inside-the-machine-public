#!/usr/bin/env node
const yargs = require('yargs/yargs')
const { hideBin } = require('yargs/helpers')
const argv = yargs(hideBin(process.argv)).argv

const fs = require("fs")

const inputFile = argv._[0]
if (!inputFile) {
  console.error('no input file')
  process.exit(1)
}
const outputFile = argv._[1]
if (!outputFile) {
  console.error('no output file')
  process.exit(1)
}

let output = []

const MAX_VERT = argv.scale ?? 127
const MAX_UV = argv.uvScale ?? 50
const MAX_NORM = argv.normScale ?? 64

const data = fs.readFileSync(inputFile)
const lines = data.toString().trim().split(/\n+/).map(v => v.trim())

const verts = []
const norms = []
const uvs = []
const tvs = []
let faces = []

const usedVerts = []
const usedNorms = []

const norm = max => v => Math.round(Number(v) * max)

lines.forEach(line => {
  const parts = line.split(/\s+/)
  switch (parts.shift()) {
    case 'v': {
      const v = parts.map(norm(MAX_VERT))
      verts.push([v[1], v[2], v[0]])
      break;
    }
    case 'vn':
      const v = parts.map(norm(MAX_NORM))
      norms.push([v[1], v[2], v[0]])
      break
    case 'vt':
      uvs.push(parts.map(norm(MAX_UV)))
      break
    case 'f': {
      faces.push(parts.map(p => p.split('/')))
    }
  }
})

if (argv.sortZ) {
  faces = faces.filter(f => dotProd(f) > 0)
  faces = faces.sort((a, b) => {
    return getZ(b) - getZ(a)
  })
}

function dotProd(face) {
  const [a, b, c] = getVerts(face)
  // return a[0] * b[0] + a[1] * b[1] + a[2] + b[2]
  const [x1, y1] = a
  const [x2, y2] = b
  const [x3, y3] = c
  return (y1 - y2) * (x2 - x3) - (y2 - y3) * (x1 - x2)
}

function getVerts(face) {
  return face.map(v => verts[v[0] - 1])
}


function getZ(face) {
  const zVals = getVerts(face).map(v => v[2])
  return zVals / zVals.length
}


const minVerts = Math.min(...faces.map(f => f.length))

faces.forEach(f => {
  if (f.length > minVerts) {
    // Convert quad to two tris
    // This assumes either tris or verts
    addTri([f[0], f[1], f[2]])
    addTri([f[0], f[2], f[3]])
  } else {
    addTri(f)
  }
})

function addTri(f) {
  f.forEach(v => {
    const vert = verts[v[0] - 1]
    if (!usedVerts.includes(vert)) usedVerts.push(vert)
    if (argv.normals) {
      const norm = norms[v[2] - 1]
      if (!usedNorms.includes(norm)) usedNorms.push(norm)
      tvs.push([usedVerts.indexOf(vert), usedNorms.indexOf(norm)])
    } else {
      tvs.push([usedVerts.indexOf(vert), ...uvs[v[1] - 1]])
    }
  })
}

const type = []
if (argv.normals) {
  type.push('OBJTYPE_NORM')
}
if (minVerts > 3) {
  type.push('OBJTYPE_QUAD')
}

const name = 'Obj_' + hashCode(inputFile)

output.push('\t\tinclude 3d.i\n')

output.push(name + ':')
output.push(`\t\tdc.w .verts-${name}`)
if (argv.normals) {
  output.push(`\t\tdc.w .norms-${name}`)
} else {
  output.push(`\t\tdc.w 0`)
}
output.push(`\t\tdc.w .faces-${name}`)
output.push(`\t\tdc.w ${type.join('!') || 0}`)

output.push('.verts:')
output.push('\t\tCOUNT\t' + usedVerts.length)
usedVerts.forEach(v => output.push('\t\tVEC3\t' + v.join(',')))

if (argv.normals) {
  output.push('.norms:')
  output.push('\t\tCOUNT\t' + usedNorms.length)
  usedNorms.forEach(v => output.push('\t\tVEC3\t' + v.join(',')))
  output.push('.faces:')
  output.push('\t\tCOUNT\t' + faces.length)
  tvs.forEach(v => output.push('\t\tNV\t' + v.join(',')))
} else {
  norms.forEach(v => output.push('\t\tVEC3\t' + v.join(',')))
  output.push('.faces:')
  output.push('\t\tCOUNT\t' + faces.length)
  tvs.forEach(v => {
    output.push('\t\tTV\t' + v.join(','))
  })
}

fs.writeFileSync(outputFile, output.join('\n'))

function hashCode(str, seed = 0) {
  let h1 = 0xdeadbeef ^ seed, h2 = 0x41c6ce57 ^ seed;
  for (let i = 0, ch; i < str.length; i++) {
    ch = str.charCodeAt(i);
    h1 = Math.imul(h1 ^ ch, 2654435761);
    h2 = Math.imul(h2 ^ ch, 1597334677);
  }
  h1 = Math.imul(h1 ^ (h1 >>> 16), 2246822507);
  h1 ^= Math.imul(h2 ^ (h2 >>> 13), 3266489909);
  h2 = Math.imul(h2 ^ (h2 >>> 16), 2246822507);
  h2 ^= Math.imul(h1 ^ (h1 >>> 13), 3266489909);

  return 4294967296 * (2097151 & h2) + (h1 >>> 0);
};
