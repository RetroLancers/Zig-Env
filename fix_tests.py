import re
import sys

def fix_env_get_calls(content):
    """Fix env.get() calls to use optional unwrapping instead of try"""
    
    # Pattern 1: const var = try env.get("KEY")
    # Replace with: const var = env.get("KEY").?
    content = re.sub(
        r'const (\w+) = try env\.get\(("[^"]+"|\'[^\']+\'|[\w_]+)\)',
        r'const \1 = env.get(\2).?',
        content
    )
    
    # Pattern 2: _ = try env.get("KEY")
    # Replace with: _ = env.get("KEY").?
    content = re.sub(
        r'_ = try env\.get\(("[^"]+"|\'[^\']+\'|[\w_]+)\)',
        r'_ = env.get(\1).?',
        content
    )
    
    return content

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python fix_tests.py <file>")
        sys.exit(1)
    
    filepath = sys.argv[1]
    
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    fixed_content = fix_env_get_calls(content)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(fixed_content)
    
    print(f"Fixed {filepath}")
