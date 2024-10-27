const fs = require('fs')

// Number of animation frames and therefore files per figure
const FRAMES = 25

// Images wider than 16px are split into slices by Kingcon
// All figures are 48px width, attached
const SPRITE_SLICES = 6

const figures = [
  { name: "sa_M4x_jogger", h: 54, w: 32 },
  { name: "sa_S4x_flyer", h: 29, w: 48 },
  { name: "sa_G4x_walker", h: 47, w: 32 },
  { name: "sa_P4x_strutter", h: 32, w: 48 },
]

// Load all the frames of all the figures
const figureBuffers = figures.map(f => {
  const buffers = []
  for (let i = 0; i < FRAMES; i++) {
    const filename = `${__dirname}/../data/${f.name}/${String(i + 1).padStart(4, '0')}.ASP`
    buffers.push(fs.readFileSync(filename))
  }
  return buffers
})

// Genreate a single file for each frame
for (let frame = 0; frame < FRAMES; frame++) {
  console.log('\nFrame: ' + (frame + 1))
  // the file will start with a table of word offsets for each of the 6 sprite slices
  const tableLength = SPRITE_SLICES * 2
  const offsetsTable = Buffer.alloc(tableLength)
  let curentOffset = tableLength // first sprite starts after offset table

  // Buffers to be concatenated for frame file
  const frameBuffers = [offsetsTable]

  // for each slice index, combine nth slice of each figure
  for (let spr = 0; spr < SPRITE_SLICES; spr++) {
    console.log('--------------------------------------------------------------------------------')
    console.log('Sprite slice: ' + spr)
    // combine the nth slice from each figure
    const sliceBuffers = []

    for (let fig = 0; fig < figures.length; fig++) {
      const maxSlice = fig.w / 16 * 2 - 1
      console.log(figures[fig].name)
      if (spr > maxSlice) continue
      // Get length of slice from figure height
      const sliceLength = figures[fig].h * 4 + 4

      const figFrameBuffer = figureBuffers[fig][frame]

      // Extract each slice by byte range
      // Kingcon gives us the start offset for each slice
      const start = figFrameBuffer.readInt16BE(spr * 2)
      const end = start + sliceLength
      console.log(`from ${start} to ${end}`)
      sliceBuffers.push(figFrameBuffer.slice(start, end))
    }

    // alloc 4 additional bytes for end control words
    sliceBuffers.push(Buffer.alloc(4))
    // Concat and add to frame
    const combinedSlice = Buffer.concat(sliceBuffers)
    frameBuffers.push(combinedSlice)

    // Write offset to table and increment
    offsetsTable.writeInt16BE(curentOffset, spr * 2)
    curentOffset += combinedSlice.length
  }

  // Concat and output file
  const filename = `${__dirname}/../data/Sprites-${String(frame + 1).padStart(4, '0')}.ASP`
  console.log('--------------------------------------------------------------------------------')
  console.log(`writing ${filename}`)
  fs.writeFileSync(filename, Buffer.concat(frameBuffers))
}
