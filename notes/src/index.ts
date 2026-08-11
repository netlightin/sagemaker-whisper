import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const transcribedDir = path.join(__dirname, "../transcribed");
const outputDir = path.join(__dirname, "../output");
const outputFile = path.join(outputDir, "combined.txt");

// Create output directory if it doesn't exist
if (!fs.existsSync(outputDir)) {
  fs.mkdirSync(outputDir, { recursive: true });
}

const files = fs.readdirSync(transcribedDir).sort((a: string, b: string) => {
  // Extract datetime from filename: chunk_MM_DD_YYYY__HH_MM_SS.txt
  const dateTimeA = a.match(/chunk_(.+)\.txt/)?.[1] || "";
  const dateTimeB = b.match(/chunk_(.+)\.txt/)?.[1] || "";
  return dateTimeA.localeCompare(dateTimeB);
});

let combinedContent = "";

files.forEach((file: string) => {
  const filePath = path.join(transcribedDir, file);
  const content = fs.readFileSync(filePath, "utf-8");
  const dateTime = file.match(/chunk_(.+)\.txt/)?.[1] || file;
  combinedContent += `[${dateTime}] ${content}\n`;
});

fs.writeFileSync(outputFile, combinedContent);
console.log(`Combined file created at: ${outputFile}`);
