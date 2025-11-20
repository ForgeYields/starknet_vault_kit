import { readFileSync, writeFileSync } from 'fs';

interface LeafAdditionalData {
  decoder_and_sanitizer: string;
  target: string;
  selector: string;
  argument_addresses: string[];
  description: string;
  leaf_index: number;
  leaf_hash: string;
}

interface Metadata {
  vault: string;
  vault_allocator: string;
  manager: string;
  decoder_and_sanitizer: string;
  root: string;
  tree_capacity: number;
  leaf_used: number;
}

interface MerkleDocument {
  metadata: Metadata;
  leafs: LeafAdditionalData[];
  tree: string[][];
}

function main() {
  const args = process.argv.slice(2);

  if (args.length < 2) {
    console.error('Usage: tsx exportMerkle.ts <log_path> <out_path>');
    process.exit(1);
  }

  const [logPath, outPath] = args;
  const s = readFileSync(logPath, 'utf-8');

  // Helper function to extract metadata fields
  const get = (key: string): string => {
    const pattern = new RegExp(`^${key}:\\s*([0-9]+)\\s*$`, 'm');
    const match = s.match(pattern);
    return match ? match[1] : '';
  };

  // Extract leaf additional data
  const leafBlock = s.match(/leaf_additional_data:\s*\[(.*)\]\s*tree:/s);
  const items = leafBlock
    ? [...leafBlock[1].matchAll(/ManageLeafAdditionalData\s*\{(.*?)\}/gs)]
    : [];

  const leafs: LeafAdditionalData[] = items.map((item) => {
    const content = item[1];

    const g = (pattern: string): string => {
      const match = content.match(new RegExp(pattern, 's'));
      return match ? match[1] : '';
    };

    const argMatch = content.match(/argument_addresses:\s*\[(.*?)\]/s);
    const args = argMatch ? [...argMatch[1].matchAll(/[0-9]+/g)].map(m => m[0]) : [];

    return {
      decoder_and_sanitizer: g(String.raw`decoder_and_sanitizer:\s*([0-9]+)`),
      target: g(String.raw`target:\s*([0-9]+)`),
      selector: g(String.raw`selector:\s*([0-9]+)`),
      argument_addresses: args,
      description: g(String.raw`description:\s*"([^"]*)"`),
      leaf_index: parseInt(g(String.raw`leaf_index:\s*([0-9]+)`) || '0', 10),
      leaf_hash: g(String.raw`leaf_hash:\s*([0-9]+)`),
    };
  });

  // Extract tree via bracket counting
  const tree: string[][] = [];
  const treeStart = s.indexOf('tree:');

  if (treeStart !== -1) {
    const bracketStart = s.indexOf('[', treeStart);

    if (bracketStart !== -1) {
      let depth = 0;
      let buf = '';

      for (const ch of s.slice(bracketStart)) {
        buf += ch;
        if (ch === '[') depth++;
        else if (ch === ']') depth--;
        if (depth === 0) break;
      }

      const rowMatches = [...buf.matchAll(/\[([0-9,\s]+)\]/g)];
      for (const row of rowMatches) {
        const numbers = [...row[1].matchAll(/[0-9]+/g)].map(m => m[0]);
        tree.push(numbers);
      }
    }
  }

  // Build the output document
  const doc: MerkleDocument = {
    metadata: {
      vault: get('vault'),
      vault_allocator: get('vault_allocator'),
      manager: get('manager'),
      decoder_and_sanitizer: get('decoder_and_sanitizer'),
      root: get('root'),
      tree_capacity: parseInt(get('tree_capacity') || '0', 10),
      leaf_used: parseInt(get('leaf_used') || '0', 10),
    },
    leafs,
    tree,
  };

  // Write output
  writeFileSync(outPath, JSON.stringify(doc, null, 2), 'utf-8');
  console.log(`Wrote ${outPath}  (log: ${logPath})`);
}

main();
