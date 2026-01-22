import re

file_path = r'd:\qurani\cuda_qurani\pubspec.yaml'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace existing font asset paths
pattern = r'asset: assets/fonts/QPCV4Font/p(\d+)\.ttf'
replacement = r'asset: assets/QPCv2/QPC V2 Font.ttf/p\1.ttf'

new_content = re.sub(pattern, replacement, content)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(new_content)

print("Updated font paths in pubspec.yaml")
