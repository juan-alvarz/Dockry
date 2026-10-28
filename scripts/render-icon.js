// Renders App/AppIcon.svg into the PNG sizes of a macOS .iconset, with Playwright:
//   node scripts/render-icon.js App/AppIcon.svg App/AppIcon.iconset
const { chromium } = require('playwright');
const fs = require('fs');
const [svgPath, outDir] = process.argv.slice(2);
const svg = fs.readFileSync(svgPath, 'utf8');
const sizes = [[16, 1], [16, 2], [32, 1], [32, 2], [128, 1], [128, 2], [256, 1], [256, 2], [512, 1], [512, 2]];
(async () => {
  const browser = await chromium.launch();
  for (const [size, scale] of sizes) {
    const px = size * scale;
    const page = await browser.newPage({ viewport: { width: px, height: px } });
    await page.setContent(`<html><body style="margin:0;background:transparent">${svg.replace('width="1024" height="1024"', `width="${px}" height="${px}"`)}</body></html>`);
    const name = `icon_${size}x${size}${scale === 2 ? '@2x' : ''}.png`;
    await page.screenshot({ path: `${outDir}/${name}`, omitBackground: true, clip: { x: 0, y: 0, width: px, height: px } });
    await page.close();
  }
  await browser.close();
})();
