#!/usr/bin/env python
import yaml
import sys
from pathlib import Path

def extract_labels(yaml_path: Path, out_path: Path):
    # Load the YAML
    data = yaml.safe_load(yaml_path.read_text())
    names = data.get("names") or data.get("classes") or {}
    # names is a dict mapping int->string
    # Write them in ascending key order, one per line
    with out_path.open("w") as f:
        for idx in sorted(names, key=lambda x: int(x)):
            f.write(f"{names[idx]}\n")

if __name__ == "__main__":
    # Usage: ./extract_labels.py path/to/coco128.yaml labels.txt
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <input.yaml> <output.txt>", file=sys.stderr)
        sys.exit(1)
    extract_labels(Path(sys.argv[1]), Path(sys.argv[2]))
