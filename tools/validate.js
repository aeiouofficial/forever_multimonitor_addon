"use strict";

const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const toc = fs.readFileSync(path.join(root, "ForeverMultiMonitor.toc"), "utf8");
const failures = [];
const required = [
  "Core/Bootstrap.lua", "Core/Compat.lua", "Core/Config.lua", "Core/RawMouse.lua",
  "Core/Geometry.lua", "Core/Viewport.lua", "Core/PanelRegistry.lua", "Core/PanelControllers.lua", "Core/Panels.lua",
  "Core/Recovery.lua", "Core/Commands.lua", "Core/Init.lua",
];

function assert(condition, message) {
  if (!condition) failures.push(message);
}

function tokenizeLua(source) {
  const tokens = [];
  let i = 0;
  while (i < source.length) {
    const c = source[i];
    if (/\s/.test(c)) { i++; continue; }

    if (source.startsWith("--", i)) {
      const long = source.slice(i).match(/^--\[(=*)\[/);
      if (long) {
        const close = "]" + long[1] + "]";
        const end = source.indexOf(close, i + long[0].length);
        i = end < 0 ? source.length : end + close.length;
      } else {
        const end = source.indexOf("\n", i + 2);
        i = end < 0 ? source.length : end + 1;
      }
      continue;
    }

    if (c === "'" || c === '"') {
      const quote = c;
      i++;
      while (i < source.length) {
        if (source[i] === "\\") { i += 2; continue; }
        if (source[i] === quote) { i++; break; }
        i++;
      }
      tokens.push({ type: "string", value: "STRING" });
      continue;
    }

    const longString = source.slice(i).match(/^\[(=*)\[/);
    if (longString) {
      const close = "]" + longString[1] + "]";
      const end = source.indexOf(close, i + longString[0].length);
      i = end < 0 ? source.length : end + close.length;
      tokens.push({ type: "string", value: "STRING" });
      continue;
    }

    const identifier = source.slice(i).match(/^[A-Za-z_][A-Za-z0-9_]*/);
    if (identifier) {
      tokens.push({ type: "identifier", value: identifier[0] });
      i += identifier[0].length;
      continue;
    }

    if ("(){}[]".includes(c)) tokens.push({ type: "delimiter", value: c });
    i++;
  }
  return tokens;
}

function checkLuaStructure(file, source) {
  const tokens = tokenizeLua(source);
  const blocks = [];
  const delimiters = [];
  let pendingLoopDo = 0;

  for (const token of tokens) {
    if (token.type === "delimiter") {
      if ("([{".includes(token.value)) delimiters.push(token.value);
      else {
        const expected = { ")": "(", "]": "[", "}": "{" }[token.value];
        if (delimiters.pop() !== expected) failures.push(file + ": mismatched delimiter " + token.value);
      }
      continue;
    }
    if (token.type !== "identifier") continue;

    const word = token.value;
    if (word === "function" || word === "if" || word === "repeat") {
      blocks.push(word);
    } else if (word === "for" || word === "while") {
      blocks.push(word);
      pendingLoopDo++;
    } else if (word === "do") {
      if (pendingLoopDo > 0) pendingLoopDo--;
      else blocks.push("do");
    } else if (word === "end") {
      const top = blocks.pop();
      if (!top || top === "repeat") failures.push(file + ": unexpected 'end'");
    } else if (word === "until") {
      if (blocks.pop() !== "repeat") failures.push(file + ": 'until' without matching 'repeat'");
    }
  }

  if (blocks.length) failures.push(file + ": unclosed Lua block(s): " + blocks.join(", "));
  if (delimiters.length) failures.push(file + ": unclosed delimiter(s): " + delimiters.join(""));
}

assert(/^## Interface:\s*16001$/m.test(toc), "TOC must target Interface 16001");
assert(/^## AllowLoadGameType:\s*camelot$/m.test(toc), "TOC must declare Camelot game type");

const listed = toc.split(/\r?\n/)
  .map((line) => line.trim().replace(/\\/g, "/"))
  .filter((line) => line.endsWith(".lua"));

for (const file of required) assert(listed.includes(file), "TOC missing required module: " + file);

for (const file of listed) {
  const absolute = path.join(root, file);
  assert(fs.existsSync(absolute), "TOC references missing file: " + file);
  if (!fs.existsSync(absolute)) continue;

  const source = fs.readFileSync(absolute, "utf8");
  checkLuaStructure(file, source);
  assert(!/\b(?:io|os|debug)\s*\./.test(source), "Forbidden Lua standard library access: " + file);
  assert(!/\b(?:loadstring|dofile|loadfile)\s*\(/.test(source), "Dynamic Lua code loading: " + file);
}

if (failures.length) {
  console.error("VALIDATION FAILED");
  for (const failure of failures) console.error(" - " + failure);
  process.exitCode = 1;
} else {
  console.log("PASS: Forever manifest, " + listed.length + " TOC Lua files, Lua structure, and sandbox checks.");
  console.log("NOTE: This is a structural validator, not a full Lua parser; live client tests remain mandatory.");
}
