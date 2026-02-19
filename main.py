import os
import time
from datetime import datetime

REPO_PATH = "$HOME/congenial-doodle"
BRANCH = "main"
INTERVAL = 3600  # seconds

while True:
    os.chdir(REPO_PATH)
    
    os.system(f"git pull origin {BRANCH}")
    os.system("git add .")
    
    commit_message = f"🤖 Auto commit: {datetime.now()}"
    os.system(f'git commit -m "{commit_message}"')
    os.system(f"git push origin {BRANCH}")
    
    time.sleep(INTERVAL)
