import { build, context } from 'esbuild'
import CoffeeScript from 'coffeescript'
import { mkdir, readFile, rm } from 'node:fs/promises'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const rootDir = dirname(fileURLToPath(import.meta.url))
const projectRoot = resolve(rootDir, '..')
const distDir = resolve(projectRoot, 'dist')
const entryPoint = resolve(projectRoot, 'src/index.js')

const coffeePlugin = {
  name: 'coffeescript',
  setup(buildCtx) {
    buildCtx.onLoad({ filter: /\.coffee$/ }, async (args) => {
      const source = await readFile(args.path, 'utf8')
      const compiled = CoffeeScript.compile(source, {
        bare: true,
        filename: args.path
      })

      return {
        contents: compiled,
        loader: 'js'
      }
    })
  }
}

const shared = {
  entryPoints: [entryPoint],
  bundle: true,
  sourcemap: true,
  plugins: [coffeePlugin],
  logLevel: 'info',
  target: ['es2018']
}

const targets = [
  { format: 'esm', outfile: 'index.js' },
  { format: 'cjs', outfile: 'index.cjs' },
  {
    format: 'iife',
    outfile: 'pjax.global.js',
    banner: { js: 'var Pjax;' },
    footer: { js: 'if (typeof window !== "undefined") Pjax = window.Pjax;' }
  }
]

const args = process.argv.slice(2)
const isWatch = args.includes('--watch') || args.includes('-w')

function withDistPaths(opts) {
  const filePath = resolve(distDir, opts.outfile)
  return {
    ...shared,
    ...opts,
    outfile: filePath
  }
}

async function main() {
  await rm(distDir, { recursive: true, force: true })
  await mkdir(distDir, { recursive: true })

  const options = targets.map(withDistPaths)

  if (isWatch) {
    const contexts = []

    for (const opts of options) {
      const ctx = await context(opts)
      await ctx.watch()
      contexts.push(ctx)
    }

    console.log('PJAX build watching... (press Ctrl+C to stop)')

    const shutdown = async () => {
      await Promise.all(contexts.map((ctx) => ctx.dispose()))
      process.exit(0)
    }

    process.on('SIGINT', shutdown)
    process.on('SIGTERM', shutdown)
    process.stdin.resume()
    return
  }

  await Promise.all(options.map((opts) => build(opts)))
  console.log('PJAX build complete')
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
