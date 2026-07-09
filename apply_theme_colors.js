const fs = require('fs');
const path = require('path');

const projectRoot = 'e:\\workout-tracker-abdul';
const libDir = path.join(projectRoot, 'lib');

function walkDir(dir, callback) {
  fs.readdirSync(dir).forEach(f => {
    let dirPath = path.join(dir, f);
    let isDirectory = fs.statSync(dirPath).isDirectory();
    if (isDirectory) {
      walkDir(dirPath, callback);
    } else {
      callback(dirPath);
    }
  });
}

const colorReplacements = [
  { regex: /const\s+Color\(0xFF030712\)/g, replacement: 'AppTheme.background' },
  { regex: /Color\(0xFF030712\)/g, replacement: 'AppTheme.background' },
  { regex: /const\s+Color\(0xFF111827\)/g, replacement: 'AppTheme.surface' },
  { regex: /Color\(0xFF111827\)/g, replacement: 'AppTheme.surface' },
  { regex: /const\s+Color\(0xFF1F2937\)/g, replacement: 'AppTheme.border' },
  { regex: /Color\(0xFF1F2937\)/g, replacement: 'AppTheme.border' },
  { regex: /const\s+Color\(0xFF374151\)/g, replacement: 'AppTheme.borderLight' },
  { regex: /Color\(0xFF374151\)/g, replacement: 'AppTheme.borderLight' },
];

const constFixes = [
  // Remove const from container decoration and border definitions
  { regex: /const\s+BoxDecoration\(/g, replacement: 'BoxDecoration(' },
  { regex: /const\s+Border\(/g, replacement: 'Border(' },
  { regex: /const\s+BorderSide\(/g, replacement: 'BorderSide(' },
  { regex: /const\s+RoundedRectangleBorder\(/g, replacement: 'RoundedRectangleBorder(' },
  { regex: /const\s+UnderlineInputBorder\(/g, replacement: 'UnderlineInputBorder(' },
  { regex: /const\s+OutlineInputBorder\(/g, replacement: 'OutlineInputBorder(' },
  { regex: /const\s+InputDecoration\(/g, replacement: 'InputDecoration(' },
];

walkDir(libDir, filePath => {
  if (path.extname(filePath) !== '.dart') return;
  // Skip the theme file itself
  if (filePath.endsWith('app_theme.dart')) return;

  let content = fs.readFileSync(filePath, 'utf8');
  let original = content;

  // 1. Perform color replacements
  for (let rep of colorReplacements) {
    content = content.replace(rep.regex, rep.replacement);
  }

  // 2. Perform const fixes to prevent compile issues with dynamic colors
  for (let fix of constFixes) {
    content = content.replace(fix.regex, fix.replacement);
  }

  // 3. Add import statement if file was modified
  if (content !== original) {
    // Only import if not already imported
    if (!content.includes("import '../theme/app_theme.dart';") && !content.includes("import 'theme/app_theme.dart';")) {
      // Find the first import statement and insert it after
      const importIndex = content.indexOf('import ');
      if (importIndex !== -1) {
        const lineEnd = content.indexOf('\n', importIndex);
        const relativePath = filePath.includes('screens') || filePath.includes('widgets') || filePath.includes('services')
          ? "import '../theme/app_theme.dart';"
          : "import 'theme/app_theme.dart';";
        content = content.substring(0, lineEnd + 1) + `${relativePath}\n` + content.substring(lineEnd + 1);
      }
    }
    
    fs.writeFileSync(filePath, content, 'utf8');
    console.log(`Updated colors and consts in: ${path.basename(filePath)}`);
  }
});

console.log('Replacement task completed!');
