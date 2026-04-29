#!/bin/bash
# User data script for EC2 instances in Auto Scaling Group
# This script installs a web server and stress testing tools

# Update system
yum update -y

# Install Apache web server
yum install -y httpd

# Install stress testing tool
amazon-linux-extras install epel -y
yum install -y stress

# Get instance metadata
INSTANCE_ID=$(ec2-metadata --instance-id | cut -d " " -f 2)
AVAILABILITY_ZONE=$(ec2-metadata --availability-zone | cut -d " " -f 2)
LOCAL_IPV4=$(ec2-metadata --local-ipv4 | cut -d " " -f 2)

# Create web page with instance information
cat > /var/www/html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Auto Scaling Demo</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 800px;
            margin: 50px auto;
            padding: 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        .container {
            background: rgba(255, 255, 255, 0.1);
            padding: 30px;
            border-radius: 10px;
            backdrop-filter: blur(10px);
        }
        h1 { margin-top: 0; }
        .info { 
            background: rgba(255, 255, 255, 0.2);
            padding: 15px;
            border-radius: 5px;
            margin: 10px 0;
        }
        .label { font-weight: bold; }
        .metrics {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 15px;
            margin-top: 20px;
        }
        .metric {
            background: rgba(255, 255, 255, 0.2);
            padding: 15px;
            border-radius: 5px;
            text-align: center;
        }
        .metric-value {
            font-size: 2em;
            font-weight: bold;
            margin: 10px 0;
        }
        button {
            background: #4CAF50;
            color: white;
            border: none;
            padding: 10px 20px;
            font-size: 16px;
            border-radius: 5px;
            cursor: pointer;
            margin: 5px;
        }
        button:hover { background: #45a049; }
        button.danger { background: #f44336; }
        button.danger:hover { background: #da190b; }
    </style>
    <script>
        function updateMetrics() {
            fetch('/metrics')
                .then(response => response.json())
                .then(data => {
                    document.getElementById('cpu').textContent = data.cpu + '%';
                    document.getElementById('memory').textContent = data.memory + '%';
                    document.getElementById('requests').textContent = data.requests;
                })
                .catch(error => console.error('Error:', error));
        }
        
        function startStress() {
            fetch('/stress/start', { method: 'POST' })
                .then(response => response.json())
                .then(data => alert(data.message));
        }
        
        function stopStress() {
            fetch('/stress/stop', { method: 'POST' })
                .then(response => response.json())
                .then(data => alert(data.message));
        }
        
        setInterval(updateMetrics, 2000);
        window.onload = updateMetrics;
    </script>
</head>
<body>
    <div class="container">
        <h1>🚀 Auto Scaling Group Demo</h1>
        
        <div class="info">
            <div><span class="label">Instance ID:</span> INSTANCE_ID_PLACEHOLDER</div>
            <div><span class="label">Availability Zone:</span> AZ_PLACEHOLDER</div>
            <div><span class="label">Private IP:</span> IP_PLACEHOLDER</div>
        </div>
        
        <h2>Real-time Metrics</h2>
        <div class="metrics">
            <div class="metric">
                <div>CPU Usage</div>
                <div class="metric-value" id="cpu">0%</div>
            </div>
            <div class="metric">
                <div>Memory Usage</div>
                <div class="metric-value" id="memory">0%</div>
            </div>
            <div class="metric">
                <div>Total Requests</div>
                <div class="metric-value" id="requests">0</div>
            </div>
            <div class="metric">
                <div>Status</div>
                <div class="metric-value">✅ Healthy</div>
            </div>
        </div>
        
        <h2>Stress Testing</h2>
        <button onclick="startStress()">Start CPU Stress</button>
        <button class="danger" onclick="stopStress()">Stop Stress</button>
        
        <p style="margin-top: 20px; font-size: 0.9em; opacity: 0.8;">
            This instance is part of an Auto Scaling Group. Refresh to see which instance serves your request.
        </p>
    </div>
</body>
</html>
EOF

# Replace placeholders with actual values
sed -i "s/INSTANCE_ID_PLACEHOLDER/$INSTANCE_ID/g" /var/www/html/index.html
sed -i "s/AZ_PLACEHOLDER/$AVAILABILITY_ZONE/g" /var/www/html/index.html
sed -i "s/IP_PLACEHOLDER/$LOCAL_IPV4/g" /var/www/html/index.html

# Create metrics endpoint
cat > /var/www/cgi-bin/metrics << 'EOF'
#!/bin/bash
echo "Content-type: application/json"
echo ""

CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
MEMORY=$(free | grep Mem | awk '{printf("%.0f", $3/$2 * 100.0)}')
REQUESTS=$(cat /var/log/httpd/access_log 2>/dev/null | wc -l)

echo "{\"cpu\": \"$CPU\", \"memory\": \"$MEMORY\", \"requests\": \"$REQUESTS\"}"
EOF

chmod +x /var/www/cgi-bin/metrics

# Create stress control endpoints
cat > /var/www/cgi-bin/stress-start << 'EOF'
#!/bin/bash
echo "Content-type: application/json"
echo ""

# Start stress test (4 CPU workers for 300 seconds)
nohup stress --cpu 4 --timeout 300s > /dev/null 2>&1 &

echo "{\"message\": \"Stress test started - 4 CPU workers for 5 minutes\"}"
EOF

chmod +x /var/www/cgi-bin/stress-start

cat > /var/www/cgi-bin/stress-stop << 'EOF'
#!/bin/bash
echo "Content-type: application/json"
echo ""

pkill stress

echo "{\"message\": \"Stress test stopped\"}"
EOF

chmod +x /var/www/cgi-bin/stress-stop

# Configure Apache for CGI
cat >> /etc/httpd/conf/httpd.conf << 'EOF'

# Enable CGI
<Directory "/var/www/cgi-bin">
    AllowOverride None
    Options +ExecCGI
    Require all granted
</Directory>

# Map endpoints
ScriptAlias /metrics /var/www/cgi-bin/metrics
ScriptAlias /stress/start /var/www/cgi-bin/stress-start
ScriptAlias /stress/stop /var/www/cgi-bin/stress-stop
EOF

# Start and enable Apache
systemctl start httpd
systemctl enable httpd

# Create CloudWatch monitoring script
cat > /usr/local/bin/send-metrics.sh << 'EOF'
#!/bin/bash
INSTANCE_ID=$(ec2-metadata --instance-id | cut -d " " -f 2)
REGION=$(ec2-metadata --availability-zone | cut -d " " -f 2 | sed 's/[a-z]$//')

while true; do
    CPU=$(top -bn2 -d 0.5 | grep "Cpu(s)" | tail -1 | awk '{print $2}' | cut -d'%' -f1)
    
    aws cloudwatch put-metric-data \
        --namespace "ASG/Demo" \
        --metric-name CPUUtilization \
        --value $CPU \
        --dimensions InstanceId=$INSTANCE_ID \
        --region $REGION
    
    sleep 60
done
EOF

chmod +x /usr/local/bin/send-metrics.sh

# Start metrics collection in background
nohup /usr/local/bin/send-metrics.sh > /dev/null 2>&1 &

# Create health check endpoint
echo "OK" > /var/www/html/health.html
