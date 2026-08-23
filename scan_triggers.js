// Scan SRS document for all trigger requirements
const fs = require('fs');
const path = require('path');

const srsPath = path.join('C:', 'Users', 'shiva', 'CorporatePoolingApp', 'docs', 'SRS_Document.md');
const content = fs.readFileSync(srsPath, 'utf8');
const lines = content.split('\n');

console.log('=== SEARCHING FOR TRIGGER REFERENCES IN SRS ===\n');

lines.forEach((line, idx) => {
  if (line.toLowerCase().includes('trigger') || line.toLowerCase().includes('function') && line.toLowerCase().includes('returns trigger')) {
    console.log(`Line ${idx + 1}: ${line.trim()}`);
  }
});
