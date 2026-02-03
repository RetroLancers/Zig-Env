import re
import sys

def fix_const_to_var(content):
    """Fix const env = to var env = since env.deinit() needs mutable reference"""
    
    # Replace const env = try with var env = try
    content = re.sub(
        r'const env = try',
        r'var env = try',
        content
    )
    
    return content

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python fix_const_var.py <file>")
        sys.exit(1)
    
    filepath = sys.argv[1]
    
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    fixed_content = fix_const_to_var(content)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(fixed_content)
    
    print(f"Fixed {filepath}")
