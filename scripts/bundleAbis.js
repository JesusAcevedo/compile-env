// scripts/bundleAbis.js
const fs = require('fs');
const path = require('path');

const artifactsDir = path.join(__dirname, '../artifacts/contracts');
const outputPath = path.join(__dirname, '../realty-abi-bundle.json');

const bundle = {};

fs.readdirSync(artifactsDir).forEach(contractFolder => {
  const folderPath = path.join(artifactsDir, contractFolder);
  const stat = fs.statSync(folderPath);
  if (!stat.isDirectory()) return; // ⛔ Skip non-directories

  fs.readdirSync(folderPath).forEach(file => {
    if (file.endsWith('.json') && !file.includes('.dbg')) {
      const filePath = path.join(folderPath, file);
      const content = JSON.parse(fs.readFileSync(filePath, 'utf8'));
      bundle[path.basename(file, '.json')] = content.abi;
    }
  });
});

fs.writeFileSync(outputPath, JSON.stringify(bundle, null, 2));
console.log('✅ ABI bundle created at', outputPath);
