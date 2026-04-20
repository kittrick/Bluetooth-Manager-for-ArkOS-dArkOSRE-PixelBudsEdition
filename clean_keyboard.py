import sys

with open('lib/bt_keyboard.sh', 'r') as f:
    content = f.read()

# This is a bit risky, I'll just use a simpler method
# I'll find the first definition and keep it, then find the second and remove it.
