from pathlib import Path
import json
import hashlib

def calculate_hash(filepath):
    sha256_hash = hashlib.sha256()
    with filepath.open('rb') as f:
        for byte_block in iter(lambda: f.read(4096), b""):
            sha256_hash.update(byte_block)
    return sha256_hash.hexdigest()

def generate_hash_file(directory):
    directory = Path(directory)
    hashes = {}
    
    for filepath in directory.rglob('*'):
        if not filepath.is_file() or filepath.name == '.hash':
            continue
        relpath = (directory / filepath.relative_to(directory)).as_posix()
        hashes[relpath] = calculate_hash(filepath)
    
    with (directory / '.hash').open('w') as f:
        json.dump(hashes, f, indent=2, sort_keys=True)

if __name__ == '__main__':
    import sys
    generate_hash_file(sys.argv[1]) 