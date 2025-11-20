import sys, re, json, pathlib
log_path, out_path = sys.argv[1], sys.argv[2]
s = pathlib.Path(log_path).read_text()

def get(k):
    m = re.search(rf"^{k}:\s*([0-9]+)\s*$", s, re.M)
    return m.group(1) if m else ""

blk = re.search(r"leaf_additional_data:\s*\[(.*)\]\s*tree:", s, re.S)
items = re.findall(r"ManageLeafAdditionalData\s*\{(.*?)\}", blk.group(1), re.S) if blk else []
leafs = []
for it in items:
    g = lambda pat: (re.search(pat, it, re.S).group(1) if re.search(pat, it, re.S) else "")
    argm = re.search(r"argument_addresses:\s*\[(.*?)\]", it, re.S)
    args = re.findall(r"[0-9]+", argm.group(1)) if argm else []
    leafs.append({
        "decoder_and_sanitizer": g(r"decoder_and_sanitizer:\s*([0-9]+)"),
        "target": g(r"target:\s*([0-9]+)"),
        "selector": g(r"selector:\s*([0-9]+)"),
        "argument_addresses": args,
        "description": g(r'description:\s*"([^"]*)"'),
        "leaf_index": int(g(r"leaf_index:\s*([0-9]+)") or 0),
        "leaf_hash": g(r"leaf_hash:\s*([0-9]+)")
    })

# tree via comptage de crochets
tree = []
start = s.find("tree:")
if start != -1:
    i = s.find("[", start)
    if i != -1:
        depth = 0; buf = ""
        for ch in s[i:]:
            buf += ch
            if ch == "[": depth += 1
            elif ch == "]": depth -= 1
            if depth == 0: break
        for row in re.findall(r"\[([0-9,\s]+)\]", buf):
            tree.append(re.findall(r"[0-9]+", row))

doc = {
    "metadata": {
        "vault": get("vault"),
        "vault_allocator": get("vault_allocator"),
        "manager": get("manager"),
        "decoder_and_sanitizer": get("decoder_and_sanitizer"),
        "root": get("root"),
        "tree_capacity": int(get("tree_capacity") or 0),
        "leaf_used": int(get("leaf_used") or 0)
    },
    "leafs": leafs,
    "tree": tree
}

pathlib.Path(out_path).write_text(json.dumps(doc, indent=2))
print(f"Wrote {out_path}  (log: {log_path})")
