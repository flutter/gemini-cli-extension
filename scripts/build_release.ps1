if (-not $env:GITHUB_REF) { $env:GITHUB_REF = "refs/tags/HEAD" }
$tagName = $env:GITHUB_REF.Substring($env:GITHUB_REF.LastIndexOf("/") + 1)
$archiveName = "win32.flutter.zip"
$exeFile = "flutter_launcher_mcp.exe"

Push-Location flutter_launcher_mcp
dart pub get
dart compile exe bin/flutter_launcher_mcp.dart -o "../$exeFile"
Pop-Location

$tempDir = "temp_archive"
New-Item -ItemType Directory -Path $tempDir

git archive --format=zip -o temp.zip $tagName gemini-extension.json commands/ LICENSE README.md flutter.md
Expand-Archive -Path temp.zip -DestinationPath $tempDir
Move-Item $exeFile $tempDir
Compress-Archive -Path "$tempDir\*" -DestinationPath $archiveName

Remove-Item -Path "temp.zip" -Force
Remove-Item -Path $tempDir -Recurse -Force

echo "ARCHIVE_NAME=$archiveName" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
