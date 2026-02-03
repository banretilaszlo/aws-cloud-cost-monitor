
@echo off

REM A script mappájára vált
cd /d %~dp0

echo 1) Version bump
python bump_version.py

echo 2) Package Lambda
powershell -Command "Compress-Archive -Path lambda\* -DestinationPath lambda.zip -Force"

echo 3) Terraform init
terraform init

echo 4) Terraform apply
terraform apply -auto-approve

echo Deploy complete!
pause

