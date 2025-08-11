# This Python script is a helper function that lists all the project tree flow/directories.
import os

with open("project_structure.txt", "w", encoding="utf-8") as f:
    for root, dirs, files in os.walk(".", topdown=True):
        # We can Skip unwanted folders
        dirs[:] = [d for d in dirs if d not in ["__pycache__", "migrations", "venv", "env", "static", "media"]]
        level = root.count(os.sep)
        indent = "  " * level
        f.write(f"{indent}{os.path.basename(root)}/\n")
        subindent = "  " * (level + 1)
        for file in files:
            f.write(f"{subindent}{file}\n")
