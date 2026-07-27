import re

file_path = r'g:\cockatiel\mobile\vocal_coach_app\lib\features\karaoke_practice\presentation\karaoke_singing_page.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# The specific lines with unnecessary const:
# lib\features\karaoke_practice\presentation\karaoke_singing_page.dart:516:25 - unnecessary_const
# lib\features\karaoke_practice\presentation\karaoke_singing_page.dart:558:27 - unnecessary_const

# We can just remove "const " inside the children array for the Row since the Row is already const
content = content.replace('children: const [', 'children: [')

# Or more specifically: 
content = content.replace('const Icon', 'Icon')
content = content.replace('const SizedBox', 'SizedBox')
content = content.replace('const Text', 'Text')

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Fixed!")
