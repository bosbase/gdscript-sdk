#!/usr/bin/env python3
"""
Helper script to convert JS SDK documentation to GDScript SDK documentation.
This script handles basic conversions but manual review is still needed.
"""

import os
import re
import sys

def convert_js_to_gdscript(content):
    """Convert JavaScript code examples to GDScript."""
    
    # Replace import statements
    content = re.sub(
        r"import BosBase from 'bosbase';",
        r"var BosBase = preload(\"res://gdscript-sdk/src/bosbase.gd\")",
        content
    )
    
    # Replace const/let/var declarations
    content = re.sub(r"const pb = new BosBase\('([^']+)'\);", r"var pb = BosBase.new(\"\1\")", content)
    content = re.sub(r"const pb = new BosBase\(\"([^\"]+)\"\);", r"var pb = BosBase.new(\"\1\")", content)
    
    # Replace await calls
    content = re.sub(r"await pb\.", r"await pb.", content)
    
    # Replace console.log with print
    content = re.sub(r"console\.log\(", r"print(", content)
    content = re.sub(r"console\.error\(", r"push_error(", content)
    
    # Replace JavaScript object syntax
    content = re.sub(r"\{([^}]+):\s*([^,}]+)\}", lambda m: "{" + re.sub(r"(\w+):", r'"\1":', m.group(1)) + "}", content)
    
    # Replace arrow functions
    content = re.sub(r"\(([^)]+)\)\s*=>\s*", r"func(\1):", content)
    
    # Replace template literals
    content = re.sub(r"`([^`]+)`", r'"\1"', content)
    
    # Replace JavaScript comments
    content = re.sub(r"//", r"#", content)
    
    # Replace JavaScript array methods
    content = re.sub(r"\.forEach\(", r".for_each(", content)
    content = re.sub(r"\.map\(", r".map(", content)
    content = re.sub(r"\.filter\(", r".filter(", content)
    
    # Replace JavaScript string methods
    content = re.sub(r"\.includes\(", r".has(", content)
    
    # Replace null/undefined
    content = re.sub(r"\bnull\b", r"null", content)
    content = re.sub(r"\bundefined\b", r"null", content)
    
    # Replace true/false (keep as is, but ensure lowercase)
    content = re.sub(r"\bTrue\b", r"true", content)
    content = re.sub(r"\bFalse\b", r"false", content)
    
    # Replace JavaScript SDK title
    content = re.sub(
        r"# (.*) - JavaScript SDK Documentation",
        r"# \1 - GDScript SDK Documentation",
        content
    )
    
    return content

def process_file(js_path, gd_path):
    """Process a single documentation file."""
    print(f"Processing {os.path.basename(js_path)}...")
    
    with open(js_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Convert content
    converted = convert_js_to_gdscript(content)
    
    # Write to GDScript docs directory
    os.makedirs(os.path.dirname(gd_path), exist_ok=True)
    with open(gd_path, 'w', encoding='utf-8') as f:
        f.write(converted)
    
    print(f"  Created {os.path.basename(gd_path)}")

def main():
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    js_docs_dir = os.path.join(base_dir, "js-sdk", "docs")
    gd_docs_dir = os.path.join(base_dir, "gdscript-sdk", "docs")
    
    # Files already created
    created = ["COLLECTIONS.md", "API_RECORDS.md"]
    
    # Get all JS SDK docs
    js_files = [f for f in os.listdir(js_docs_dir) if f.endswith('.md')]
    
    for js_file in js_files:
        if js_file in created:
            continue
        
        js_path = os.path.join(js_docs_dir, js_file)
        gd_path = os.path.join(gd_docs_dir, js_file)
        
        if os.path.exists(gd_path):
            print(f"Skipping {js_file} (already exists)")
            continue
        
        try:
            process_file(js_path, gd_path)
        except Exception as e:
            print(f"Error processing {js_file}: {e}")

if __name__ == "__main__":
    main()

