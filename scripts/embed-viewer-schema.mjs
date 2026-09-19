import { readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const viewerPath = path.join(root, "viewer", "index.html");
const schemaPath = path.join(root, "schema", "results-v1.schema.json");
const start = "/* embedded-schema:start */";
const end = "/* embedded-schema:end */";

const [viewer, schemaText] = await Promise.all([
  readFile(viewerPath, "utf8"),
  readFile(schemaPath, "utf8")
]);
const schema = JSON.stringify(JSON.parse(schemaText));
const pattern = new RegExp(`${start.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}[\\s\\S]*?${end.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}`);
const startCount = viewer.split(start).length - 1;
const endCount = viewer.split(end).length - 1;
if (startCount !== 1 || endCount !== 1) throw new Error("Viewer must contain exactly one embedded-schema marker pair.");
const generated = viewer.replace(pattern, `${start}${schema}${end}`);

if (generated === viewer) {
  process.exit(0);
}

if (process.argv.includes("--check")) {
  throw new Error("viewer/index.html does not contain the current Schema v1 snapshot. Run npm run build:viewer.");
}

await writeFile(viewerPath, generated);
console.log("Embedded Schema v1 into viewer/index.html.");
