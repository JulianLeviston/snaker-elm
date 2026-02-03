const esbuild = require('esbuild');
const ElmPlugin = require('esbuild-plugin-elm');
const fs = require('fs');
const path = require('path');

const distDir = path.join(__dirname, '..', 'dist');

async function buildStatic() {
  console.log('Building static P2P bundle...\n');

  // Create dist directory
  if (!fs.existsSync(distDir)) {
    fs.mkdirSync(distDir, { recursive: true });
  }

  // Build JS bundle
  console.log('Compiling Elm + TypeScript...');
  await esbuild.build({
    entryPoints: ['js/app.ts'],
    bundle: true,
    outfile: path.join(distDir, 'app.js'),
    target: 'es2020',
    sourcemap: false,
    minify: true,
    plugins: [
      ElmPlugin({
        debug: false,
        optimize: true
      })
    ]
  });

  // Copy CSS
  console.log('Copying CSS...');
  fs.copyFileSync(
    path.join(__dirname, 'css', 'app.css'),
    path.join(distDir, 'app.css')
  );

  // Copy favicon if exists
  const faviconPath = path.join(__dirname, '..', 'priv', 'static', 'favicon.ico');
  if (fs.existsSync(faviconPath)) {
    fs.copyFileSync(faviconPath, path.join(distDir, 'favicon.ico'));
  }

  // Create index.html
  console.log('Creating index.html...');
  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Snaker - P2P Multiplayer Snake</title>
  <link rel="icon" type="image/x-icon" href="favicon.ico">
  <link rel="stylesheet" href="app.css">
  <style>
    body {
      margin: 0;
      padding: 20px;
      background: #1a1a2e;
      color: #eee;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      min-height: 100vh;
    }
    #elm-app {
      max-width: 800px;
      margin: 0 auto;
    }
  </style>
</head>
<body>
  <div id="elm-app"></div>
  <script src="app.js"></script>
</body>
</html>`;

  fs.writeFileSync(path.join(distDir, 'index.html'), html);

  console.log('\n✓ Static build complete!');
  console.log(`\nOutput: ${distDir}/`);
  console.log('  - index.html');
  console.log('  - app.js');
  console.log('  - app.css');
  console.log('  - favicon.ico');
  console.log('\nTo test locally:');
  console.log('  cd dist && python3 -m http.server 8000');
  console.log('  open http://localhost:8000');
  console.log('\nTo deploy: Upload the dist/ folder to any static host.');
}

buildStatic().catch((err) => {
  console.error('Build failed:', err);
  process.exit(1);
});
