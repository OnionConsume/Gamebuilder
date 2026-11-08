// SPDX-License-Identifier: GPL-3.0-only
import { parseArgs } from 'node:util';
import { inspectGlb } from './assets.mjs';
import { createPlan, demoPlan } from './plan.mjs';
import { generateProject } from './godot.mjs';

try {
  const { values } = parseArgs({ options: {
    prompt: { type: 'string' }, out: { type: 'string' },
    character: { type: 'string' }, demo: { type: 'boolean' },
    inspect: { type: 'string' },
    model: { type: 'string' }, endpoint: { type: 'string' }, help: { type: 'boolean' },
  } });
  if (values.help) {
    console.log('Gamewright\nnode src/cli.mjs --prompt "A moon crystal hunt" --out generated/moon [--character hero.glb] [--model qwen2.5:7b]\nnode src/cli.mjs --demo --out generated/demo\nnode src/cli.mjs --inspect hero.glb\nRequires Node 22+; AI mode requires Ollama. Open the output in Godot 4.');
  } else if (values.inspect) {
    console.log(JSON.stringify(await inspectGlb(values.inspect), null, 2));
  } else {
    if (!values.out) throw new Error('Specify a new output directory with --out.');
    if (values.demo && values.prompt) throw new Error('Choose --demo or --prompt.');
    console.log(values.demo ? 'Demo mode: using a fixed plan; no AI request.' : 'Asking local AI to plan your prototype…');
    const plan = values.demo ? demoPlan : await createPlan(values.prompt, { model: values.model, endpoint: values.endpoint });
    const root = await generateProject(plan, values.out, { character: values.character });
    console.log(`Created ${plan.title} at ${root}\nOpen project.godot in Godot 4 and press F6 or F5.`);
  }
} catch (error) {
  console.error(`Gamewright: ${error.message}`);
  process.exitCode = 1;
}
