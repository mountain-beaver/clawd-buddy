// Writes the tray icons (colour for Windows, template for macOS) into assets/.
// Usage: node scripts/make-tray-icons.js
const fs = require("fs");
const path = require("path");
const zlib = require("zlib");

const OUT = path.join(__dirname, "..", "assets");

// Same 14×10 crab as the sprite: body, arms, legs, two eyes.
function cells() {
  const body = [], eyes = [];
  for (let c = 2; c < 12; c++) for (let r = 0; r < 8; r++) body.push([c, r]);
  for (const [c, r] of [[0, 4], [1, 4], [0, 5], [1, 5], [12, 4], [13, 4], [12, 5], [13, 5]]) body.push([c, r]);
  for (const c of [3, 5, 8, 10]) body.push([c, 8], [c, 9]);
  for (const c of [4, 9]) eyes.push([c, 2], [c, 3]);
  return { body, eyes };
}

function crc32(buf) {
  let c, crc = 0xffffffff;
  for (let n = 0; n < buf.length; n++) {
    c = (crc ^ buf[n]) & 0xff;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    crc = (crc >>> 8) ^ c;
  }
  return (crc ^ 0xffffffff) >>> 0;
}

function png(size, pixels) {
  const chunk = (type, data) => {
    const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
    const td = Buffer.concat([Buffer.from(type), data]);
    const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(td));
    return Buffer.concat([len, td, crc]);
  };
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(size, 0); ihdr.writeUInt32BE(size, 4);
  ihdr[8] = 8; ihdr[9] = 6; // 8-bit RGBA
  const raw = Buffer.alloc(size * (size * 4 + 1));
  for (let y = 0; y < size; y++) {
    raw[y * (size * 4 + 1)] = 0;
    pixels.copy(raw, y * (size * 4 + 1) + 1, y * size * 4, (y + 1) * size * 4);
  }
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk("IHDR", ihdr), chunk("IDAT", zlib.deflateSync(raw)), chunk("IEND", Buffer.alloc(0)),
  ]);
}

function render(size, template) {
  const u = size / 16, ox = 1 * u, oy = 3 * u;
  const px = Buffer.alloc(size * size * 4);
  const put = (c, r, rgba) => {
    for (let y = 0; y < u; y++) for (let x = 0; x < u; x++) {
      const i = ((oy + r * u + y) * size + (ox + c * u + x)) * 4;
      px[i] = rgba[0]; px[i + 1] = rgba[1]; px[i + 2] = rgba[2]; px[i + 3] = rgba[3];
    }
  };
  const { body, eyes } = cells();
  for (const [c, r] of body) put(c, r, template ? [0, 0, 0, 255] : [0xd9, 0x77, 0x57, 255]);
  for (const [c, r] of eyes) put(c, r, template ? [0, 0, 0, 0] : [0x1f, 0x14, 0x10, 255]);
  return png(size, px);
}

fs.mkdirSync(OUT, { recursive: true });
for (const [name, template] of [["tray", false], ["trayTemplate", true]]) {
  fs.writeFileSync(path.join(OUT, `${name}.png`), render(16, template));
  fs.writeFileSync(path.join(OUT, `${name}@2x.png`), render(32, template));
}
console.log("tray icons written to", OUT);
