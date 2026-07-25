import subprocess
import re
import sys
import os

def run_analyzer():
    print("Running dart analyze...")
    result = subprocess.run(["dart", "analyze"], capture_output=True, text=True)
    return result.stdout + "\n" + result.stderr

def fix_overrides():
    output = run_analyzer()
    pattern = re.compile(r"warning - (.*\.dart):(\d+):\d+ - The method doesn't override.*override_on_non_overriding_member")
    
    fixes_by_file = {}
    
    for line in output.splitlines():
        match = pattern.search(line)
        if match:
            filepath = match.group(1).strip()
            line_num = int(match.group(2))
            
            if filepath not in fixes_by_file:
                fixes_by_file[filepath] = []
            fixes_by_file[filepath].append(line_num)
            
    if not fixes_by_file:
        print("No override_on_non_overriding_member warnings found!")
        return

    total_fixed = 0
    for filepath, lines_to_fix in fixes_by_file.items():
        if not os.path.exists(filepath):
            continue
            
        with open(filepath, 'r', encoding='utf-8') as f:
            lines = f.readlines()
            
        # Sort in reverse to delete from bottom up without shifting early indices
        lines_to_fix = sorted(list(set(lines_to_fix)), reverse=True)
        
        for line_num in lines_to_fix:
            idx = line_num - 1 # 0-indexed
            if 0 <= idx < len(lines):
                # We expect @override to be on this line or the line before
                if '@override' in lines[idx]:
                    lines[idx] = lines[idx].replace('@override', '').strip() + '\n'
                    if lines[idx].strip() == '':
                        lines.pop(idx)
                    total_fixed += 1
                elif idx - 1 >= 0 and '@override' in lines[idx-1]:
                    lines[idx-1] = lines[idx-1].replace('@override', '').strip() + '\n'
                    if lines[idx-1].strip() == '':
                        lines.pop(idx-1)
                    total_fixed += 1
                    
        with open(filepath, 'w', encoding='utf-8') as f:
            f.writelines(lines)
            
    print(f"Fixed {total_fixed} override warnings across {len(fixes_by_file)} files.")

if __name__ == "__main__":
    fix_overrides()
