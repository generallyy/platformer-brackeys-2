@echo off
echo Installing dependencies...
pip install -r requirements.txt

echo Building launcher.exe...
pyinstaller --onefile --console --name launcher launcher.py

echo.
echo Done! Your exe is at: dist\launcher.exe
echo Give your friends: launcher.exe  (they don't need anything else)
pause
