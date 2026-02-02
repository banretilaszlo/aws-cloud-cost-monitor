import re

# Beolvassuk az index.html-t
with open("index.html", "r") as f:
    html = f.read()

# Keresés: const version = "vX.X.X";
match = re.search(r'const version = "v(\d+)\.(\d+)\.(\d+)"', html)
if match:
    major, minor, patch = map(int, match.groups())
    patch += 1  # növeljük a patch számot
    new_version = f'v{major}.{minor}.{patch}'
    
    # Cseréljük a verziót
    html_new = re.sub(
        r'const version = "v\d+\.\d+\.\d+"',
        f'const version = "{new_version}"',
        html
    )

    # Mentés vissza index.html-be
    with open("index.html", "w") as f:
        f.write(html_new)

    print(f"Updated version to {new_version}")
else:
    print("Version pattern not found in index.html")
