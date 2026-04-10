# build.ps1 – Windows PowerShell build script for Lab 3 Part B
# Run from the Lab3\ directory:   .\build.ps1
# Requires g++ (MinGW / MSYS2 / WSL) on PATH.

$ErrorActionPreference = 'Stop'

$SrcDir = "src"
$Sources = @(
    "$SrcDir\conv_baseline.cpp",
    "$SrcDir\conv_output_stationary.cpp",
    "$SrcDir\conv_channel_stationary.cpp",
    "$SrcDir\conv_optimized.cpp",
    "$SrcDir\tb_conv.cpp"
)
$Output = "tb_conv.exe"
$Flags  = @("-O0", "-std=c++11", "-Wall", "-Wno-unknown-pragmas", "-Wno-unused-label", "-I$SrcDir")

Write-Host "Compiling $Output ..." -ForegroundColor Cyan
& g++ @Flags -o $Output @Sources

if ($LASTEXITCODE -eq 0) {
    Write-Host "Build succeeded.`n" -ForegroundColor Green
    Write-Host "Running $Output ..." -ForegroundColor Cyan
    & ".\$Output"
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`nAll tests passed." -ForegroundColor Green
    } else {
        Write-Host "`nSome tests FAILED." -ForegroundColor Red
    }
} else {
    Write-Host "Build FAILED." -ForegroundColor Red
    exit 1
}
