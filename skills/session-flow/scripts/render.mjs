#!/usr/bin/env node
/* eslint-disable */
/**
 * render.mjs — inject a flow-graph JSON into the bundled template and write a
 * standalone HTML file. Avoids fragile inline `node -e` quoting across shells.
 *
 * Usage: node render.mjs <flow.json> <out.html>
 *
 * The template path is resolved relative to THIS script (../assets/template.html),
 * so the caller never has to know the skill's install location for the template.
 */
import fs from 'fs'
import path from 'path'
import { fileURLToPath } from 'url'

const here = path.dirname(fileURLToPath(import.meta.url))
const templatePath = path.join(here, '..', 'assets', 'template.html')

const [jsonPath, outPath] = process.argv.slice(2)
if (!jsonPath || !outPath) {
  process.stderr.write('Usage: node render.mjs <flow.json> <out.html>\n')
  process.exit(1)
}

const template = fs.readFileSync(templatePath, 'utf8')
const data = fs.readFileSync(jsonPath, 'utf8')
// Validate it parses before embedding, so we fail loudly on a bad flow file.
JSON.parse(data)
const html = template.replace('__FLOW_DATA__', () => data) // fn form: '$' in data is literal
fs.writeFileSync(outPath, html)
process.stderr.write(`Wrote ${outPath} (${html.length} bytes)\n`)
