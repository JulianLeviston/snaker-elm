const esbuild = require('esbuild');
const ElmPlugin = require('esbuild-plugin-elm');
const fs = require('fs');
const path = require('path');

const isProduction = process.env.NODE_ENV === 'production';
const isWatch = process.argv.includes('--watch');

// Copy CSS to Phoenix static folder
function copyCSS() {
  const src = path.join(__dirname, 'css', 'app.css');
  const dest = path.join(__dirname, '..', 'priv', 'static', 'css', 'app.css');
  fs.copyFileSync(src, dest);
}

async function build() {
  // Copy CSS before build
  copyCSS();

  const ctx = await esbuild.context({
    entryPoints: ['js/app.ts'],
    bundle: true,
    outdir: '../priv/static/assets',
    target: 'es2020',
    sourcemap: !isProduction,
    minify: isProduction,
    plugins: [
      ElmPlugin({
        debug: !isProduction,
        optimize: isProduction,
        clearOnWatch: true
      })
    ]
  });

  if (isWatch) {
    // Watch CSS file for changes too
    fs.watch(path.join(__dirname, 'css'), () => {
      copyCSS();
      console.log('CSS updated');
    });
    await ctx.watch();
    console.log('Watching for changes...');
  } else {
    await ctx.rebuild();
    await ctx.dispose();
  }
}

build().catch((err) => {
  console.error(err);
  process.exit(1);
});
