#!/bin/bash

# Update system
apt-get update
apt-get install -y pgbouncer postgresql-client

# Install Cloud SQL Proxy
wget https://dl.google.com/cloudsql/cloud_sql_proxy.linux.amd64 -O cloud_sql_proxy
chmod +x cloud_sql_proxy
mv cloud_sql_proxy /usr/local/bin/

# Configuration variables
PRIMARY_IP="${primary_ip}"
REPLICA_IPS="${replica_ips}"
DB_NAME="${db_name}"
DB_USER="${db_user}"
DB_PASSWORD="${db_password}"
PGBOUNCER_PASSWORD="${pgbouncer_password}"

# Create PgBouncer configuration
cat > /etc/pgbouncer/pgbouncer.ini << EOF
[databases]
${db_name}_write = host=$PRIMARY_IP port=3306 dbname=${db_name}
${db_name}_read = host=127.0.0.1 port=5433 dbname=${db_name}

[pgbouncer]
listen_addr = 0.0.0.0
listen_port = 6432
auth_type = md5
auth_file = /etc/pgbouncer/userlist.txt
admin_users = pgbouncer
pool_mode = transaction
max_client_conn = 1000
default_pool_size = 20
reserve_pool_size = 5
log_connections = 1
log_disconnections = 1
log_pooler_errors = 1
EOF

# Create user list for PgBouncer
cat > /etc/pgbouncer/userlist.txt << EOF
"pgbouncer" "md5$(echo -n "${pgbouncer_password}pgbouncer" | md5sum | cut -d' ' -f1)"
"${db_user}" "md5$(echo -n "${db_password}${db_user}" | md5sum | cut -d' ' -f1)"
EOF

# Set proper permissions
chmod 640 /etc/pgbouncer/pgbouncer.ini
chmod 640 /etc/pgbouncer/userlist.txt
chown postgres:postgres /etc/pgbouncer/pgbouncer.ini
chown postgres:postgres /etc/pgbouncer/userlist.txt

# Create systemd service for read replica load balancing
cat > /etc/systemd/system/replica-lb.service << EOF
[Unit]
Description=Read Replica Load Balancer
After=network.target

[Service]
Type=simple
User=postgres
ExecStart=/usr/local/bin/replica-lb.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Create read replica load balancer script
cat > /usr/local/bin/replica-lb.sh << 'EOF'
#!/bin/bash

REPLICA_IPS="${replica_ips}"
IFS=',' read -ra REPLICAS <<< "$REPLICA_IPS"

# Simple round-robin load balancer for read replicas
current_replica=0
total_replicas=$${#REPLICAS[@]}

# Start a simple TCP proxy that forwards to read replicas
socat TCP-LISTEN:5433,fork,reuseaddr EXEC:"/usr/local/bin/replica-forwarder.sh"
EOF

# Create replica forwarder script
cat > /usr/local/bin/replica-forwarder.sh << 'EOF'
#!/bin/bash

REPLICA_IPS="${replica_ips}"
IFS=',' read -ra REPLICAS <<< "$REPLICA_IPS"

# Get next replica in round-robin fashion
REPLICA_INDEX_FILE="/tmp/replica_index"
if [[ ! -f "$REPLICA_INDEX_FILE" ]]; then
    echo "0" > "$REPLICA_INDEX_FILE"
fi

current_index=$(cat "$REPLICA_INDEX_FILE")
replica_ip=$${REPLICAS[$current_index]}

# Move to next replica
next_index=$(( (current_index + 1) % $${#REPLICAS[@]} ))
echo "$next_index" > "$REPLICA_INDEX_FILE"

# Forward connection to selected replica
exec socat STDIO TCP:$replica_ip:3306
EOF

# Make scripts executable
chmod +x /usr/local/bin/replica-lb.sh
chmod +x /usr/local/bin/replica-forwarder.sh

# Install socat for TCP forwarding
apt-get install -y socat

# Start services
systemctl enable pgbouncer
systemctl start pgbouncer

systemctl enable replica-lb
systemctl start replica-lb

# Configure log rotation
cat > /etc/logrotate.d/pgbouncer << EOF
/var/log/pgbouncer.log {
    daily
    rotate 7
    missingok
    notifempty
    compress
    copytruncate
}
EOF

# Health check endpoint
cat > /usr/local/bin/health-check.sh << 'EOF'
#!/bin/bash

# Check if PgBouncer is running and accepting connections
if ! nc -z localhost 6432; then
    exit 1
fi

# Check if replica load balancer is running
if ! nc -z localhost 5433; then
    exit 1
fi

exit 0
EOF

chmod +x /usr/local/bin/health-check.sh

# Start health check service
cat > /etc/systemd/system/health-check.service << EOF
[Unit]
Description=Health Check Service
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/health-check.sh

[Install]
WantedBy=multi-user.target
EOF

systemctl enable health-check.service

echo "PgBouncer setup completed"