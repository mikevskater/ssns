@echo off
REM SSNS Node.js Backend Installation Script (Windows)
REM Automatically installs Node.js dependencies and registers remote plugin

echo Installing SSNS Node.js Backend...

REM Get the plugin directory
set PLUGIN_DIR=%~dp0
set NODE_PLUGIN_DIR=%PLUGIN_DIR%rplugin\node\ssns-db

REM Check if Node.js is installed
where node >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Error: Node.js is not installed
    echo Please install Node.js from https://nodejs.org/
    exit /b 1
)

echo Node.js found
node --version

REM Check if npm is installed
where npm >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Error: npm is not installed
    exit /b 1
)

echo npm found
npm --version

REM Check if global neovim package is installed
npm list -g neovim >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Installing global neovim package...
    npm install -g neovim
) else (
    echo Global neovim package already installed
)

REM Install plugin dependencies
if exist "%NODE_PLUGIN_DIR%" (
    echo Installing SSNS Node.js dependencies...
    cd /d "%NODE_PLUGIN_DIR%"
    npm install --production
    echo Dependencies installed successfully
) else (
    echo Error: Node plugin directory not found: %NODE_PLUGIN_DIR%
    exit /b 1
)

echo.
echo SSNS Node.js Backend installed successfully!
echo.
echo IMPORTANT: You must restart Neovim and run :UpdateRemotePlugins
echo Then restart Neovim again for the plugin to work.
echo.
