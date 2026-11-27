@echo off
rem Windows 실행 파일: 같은 이름의 .sh 를 Git for Windows 의 bash 로 실행
rem - 명령은 .sh 와 같음 (README 2장)
rem - 필요: Git for Windows(bash·sed·openssl·curl 포함), Docker Desktop
setlocal

rem 출력의 한글·이모지 깨짐 방지: 이 창의 코드 페이지를 UTF-8 로
rem - 끝날 때 원래 코드 페이지로 되돌림 (setlocal 은 되돌리지 않음)
for /f "tokens=2 delims=:." %%C in ('chcp') do set "OLD_CP=%%C"
chcp 65001 >nul

set "BASH_EXE=%ProgramFiles%\Git\bin\bash.exe"
if exist "%BASH_EXE%" goto run
rem 다른 위치에 설치했으면 git 의 exec-path 기준으로 찾음
rem - exec-path: <Git>/mingw64/libexec/git-core
for /f "delims=" %%P in ('git --exec-path 2^>nul') do set "BASH_EXE=%%P/../../../bin/bash.exe"
set "BASH_EXE=%BASH_EXE:/=\%"
if exist "%BASH_EXE%" goto run
echo ❌ Git for Windows 의 bash.exe 를 찾을 수 없습니다. https://git-scm.com/download/win 에서 설치한 뒤 다시 실행하세요.
set "RC=1"
goto end

:run
rem .sh 의 안내 문구에 이 .bat 으로 실행 명령을 표시
set "CALLED_AS=bin\%~nx0"
rem 경로 구분자를 / 로: .sh 가 dirname 으로 프로젝트 루트를 찾음
set "SCRIPT=%~dpn0.sh"
"%BASH_EXE%" "%SCRIPT:\=/%" %*
set "RC=%ERRORLEVEL%"

:end
chcp %OLD_CP% >nul
exit /b %RC%
