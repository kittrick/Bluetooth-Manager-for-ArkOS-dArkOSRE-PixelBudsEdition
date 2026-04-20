import subprocess
import os
import sys

def validate():
    files = ["Bluetooth Manager.sh"]
    if os.path.exists("lib"):
        for f in os.listdir("lib"):
            if f.endswith(".sh"):
                files.append(os.path.join("lib", f))
    
    errors = False
    for f in files:
        result = subprocess.run(["bash", "-n", f], capture_output=True, text=True)
        if result.returncode != 0:
            print(f"SYNTAX ERROR in {f}:")
            print(result.stderr)
            errors = True
        else:
            print(f"OK: {f}")
    
    if errors:
        sys.exit(1)

if __name__ == "__main__":
    validate()
