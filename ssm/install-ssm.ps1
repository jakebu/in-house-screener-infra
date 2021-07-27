cd/
mkdir "temp"
cd "temp"
Invoke-WebRequest `
    https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/windows_amd64/AmazonSSMAgentSetup.exe `
    -OutFile C:\temp\SSMAgent_latest.exe
Start-Process `
    -FilePath C:\temp\SSMAgent_latest.exe `
    -ArgumentList "/S"
rm -Force C:\temp\SSMAgent_latest.exe
Restart-Service AmazonSSMAgent