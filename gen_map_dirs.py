import os

# Directories to scan
ROOT_DIRS = ['spritesheets', 'sheets_definitions']
OUTPUT_FILE = 'spritesheet_dirs.txt'

def scan_dirs(root):
    dir_set = set()
    for dirpath, _, filenames in os.walk(root):
        if filenames:
            dir_set.add(os.path.normpath(dirpath))
    return dir_set

def main():
    all_dirs = set()
    for root in ROOT_DIRS:
        if os.path.isdir(root):
            print(f"Scanning {root}...")
            all_dirs.update(scan_dirs(root))
        else:
            print(f"Warning: directory '{root}' not found. Skipping.")

    with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
        for path in sorted(all_dirs):
            f.write(path + '\n')

    print(f"\nDone. {len(all_dirs)} directories written to '{OUTPUT_FILE}'.")

if __name__ == "__main__":
    main()
