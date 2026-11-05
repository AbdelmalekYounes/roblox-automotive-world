@echo off
rem Lance les tests Roblox Studio dans la VM VMware (voir docs\VM_TESTS.md).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\vm\host-run.ps1" %*
