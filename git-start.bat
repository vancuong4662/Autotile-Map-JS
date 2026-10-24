@echo off

set /p commitMsg=Enter initial commit message: 
set /p repoUrl=Enter git repository URL: 

git init
git add .
git commit -m "%commitMsg%"
git branch -M master
git remote add origin %repoUrl%
git push -u origin master

echo Successfully first push to GitHub!
pause