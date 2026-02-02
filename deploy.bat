
cd C:\Users\Lenovo\Desktop\AWS_training\cloud-cost-monitor

@echo off
echo 1️⃣ Növeljük az index.html verziót
python bump_version.py

echo 2️⃣ Zipeljük a Lambda-t
powershell Compress-Archive C:\Users\Lenovo\Desktop\AWS_training\cloud-cost-monitor\lambda\* -DestinationPath C:\Users\Lenovo\Desktop\AWS_training\cloud-cost-monitor\lambda.zip -Force

echo 3️⃣ Terraform init
terraform init

echo 4️⃣ Terraform apply
terraform apply -auto-approve

echo ✅ Deploy kész!
pause
