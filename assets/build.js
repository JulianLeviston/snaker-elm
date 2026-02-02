const esbuild = require('esbuild');
const ElmPlugin = require('esbuild-plugin-elm');

const isProduction = process.env.NODE_ENV === 'production';
const isWatch = process.argv.includes('--watch');

async function build() {
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
