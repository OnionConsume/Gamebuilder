export const demoPlan = {
  title: 'Crystal Garden',
  description: 'Explore a small arena and collect every crystal.',
  speed: 6,
  jumpVelocity: 7,
  collectibleCount: 12,
  arenaSize: 30,
  background: '#182438',
};

export function validatePlan(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('AI must return a game plan object.');
  const plan = {};
  for (const key of ['title', 'description']) {
    if (typeof value[key] !== 'string' || !value[key].trim() || value[key].length > 300) throw new Error(`Invalid ${key}.`);
    plan[key] = value[key].trim();
  }
  for (const [key, min, max, integer] of [
    ['speed', 1, 20, false], ['jumpVelocity', 1, 20, false],
    ['collectibleCount', 1, 100, true], ['arenaSize', 10, 100, false],
  ]) {
    const n = value[key];
    if (typeof n !== 'number' || !Number.isFinite(n) || n < min || n > max || (integer && !Number.isInteger(n))) throw new Error(`Invalid ${key}: expected ${min}–${max}.`);
    plan[key] = n;
  }
  if (typeof value.background !== 'string' || !/^#[0-9a-f]{6}$/i.test(value.background)) throw new Error('Invalid background color.');
  plan.background = value.background;
  return plan;
}

export async function createPlan(prompt, { endpoint = 'http://127.0.0.1:11434', model = 'qwen2.5:7b', fetchImpl = fetch } = {}) {
  if (!prompt?.trim()) throw new Error('A game description is required.');
  const url = new URL('/api/chat', endpoint);
  const response = await fetchImpl(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    signal: AbortSignal.timeout(120000),
    body: JSON.stringify({ model, stream: false, format: 'json', messages: [
      { role: 'system', content: `Design a small third-person collectible arena for Godot. Return only JSON with exactly these fields: title (short string), description (short string), speed (number 1–20), jumpVelocity (number 1–20), collectibleCount (integer 1–100), arenaSize (number 10–100), background (hex color #RRGGBB). Only this game type is supported; adapt the user's idea to it. Do not return code or file paths.` },
      { role: 'user', content: prompt },
    ] }),
  });
  if (!response.ok) throw new Error(`AI service returned HTTP ${response.status}. Check Ollama and the model name.`);
  const result = await response.json();
  let value;
  try { value = JSON.parse(result.message.content); } catch { throw new Error('AI returned invalid JSON. Try again.'); }
  return validatePlan(value);
}
