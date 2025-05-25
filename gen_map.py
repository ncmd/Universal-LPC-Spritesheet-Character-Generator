import os

# Change this if needed
ROOT_DIRS = ['spritesheets', 'sheets_definitions']
OUTPUT_FILE = 'spritesheet_paths.txt'

def scan_directory_tree(root):
    all_paths = []
    for dirpath, dirnames, filenames in os.walk(root):
        for filename in filenames:
            rel_path = os.path.join(dirpath, filename)
            all_paths.append(os.path.normpath(rel_path))
    return all_paths

def main():
    all_paths = []
    for root in ROOT_DIRS:
        if os.path.isdir(root):
            print(f"Scanning {root}...")
            all_paths.extend(scan_directory_tree(root))
        else:
            print(f"Warning: directory '{root}' not found. Skipping.")

    with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
        for path in sorted(all_paths):
            f.write(path + '\n')

    print(f"\nDone. {len(all_paths)} paths written to '{OUTPUT_FILE}'.")

if __name__ == "__main__":
    main()
