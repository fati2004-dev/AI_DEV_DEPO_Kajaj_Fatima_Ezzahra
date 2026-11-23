@echo off
"%~dp0python\python.exe" -m sentiment_app %*
exit /b %errorlevel%
