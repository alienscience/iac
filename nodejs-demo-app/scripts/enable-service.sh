
# Clone repository
git clone 'https://github.com/mbeham/nodejs-demo-app.git' 'sample-node-app'

# Install dependencies
cd sample-node-app
npm install

# Enable Service
sudo bash -e <<EOF
cp /home/ubuntu/sample-node-app/contrib/hello.service /etc/systemd/system/hello.service
systemctl enable hello
EOF
