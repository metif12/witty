unmarked_terminal_lines = 0
unmarked_terminal_files = 0

with open('/Users/alexander/code/3rd/ghostty/files.txt') as f:
  for line in f:
      line = line.strip()
      if not line:
          continue
      parts = line.split()
      if len(parts) < 2:
          continue
      val, path = parts[0], parts[1]
      is_marked = val.startswith('+') or val.startswith('*')

      # Only process unmarked files in ./src/XXXX
      if not is_marked and '/src/input/' in path:
          try:
              with open('/Users/alexander/code/3rd/ghostty/' + path) as src:
                  n = sum(1 for _ in src)
                  unmarked_terminal_lines += n
                  unmarked_terminal_files += 1
                  print(f'{n:6,} {path}')
          except:
              pass

print()
print(f'Unmarked ./src/terminal/ files: {unmarked_terminal_files} files, {unmarked_terminal_lines:,} lines')
