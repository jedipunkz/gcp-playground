import base64
import json
import os
import logging
from google.cloud import sql_v1
from google.cloud import monitoring_v3
from datetime import datetime, timedelta

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def autoscale_replicas(event, context):
    """
    Cloud Function to autoscale Cloud SQL read replicas based on metrics
    """
    try:
        # Parse environment variables
        project_id = os.environ['PROJECT_ID']
        region = os.environ['REGION']
        primary_instance_name = os.environ['PRIMARY_INSTANCE_NAME']
        min_replica_count = int(os.environ['MIN_REPLICA_COUNT'])
        max_replica_count = int(os.environ['MAX_REPLICA_COUNT'])
        cpu_threshold_high = float(os.environ['CPU_THRESHOLD_HIGH'])
        cpu_threshold_low = float(os.environ['CPU_THRESHOLD_LOW'])
        connection_threshold_high = int(os.environ['CONNECTION_THRESHOLD_HIGH'])

        # Initialize clients
        sql_client = sql_v1.SqlInstancesServiceClient()
        monitoring_client = monitoring_v3.MetricServiceClient()

        # Get current replica count
        current_replicas = get_current_replica_count(sql_client, project_id, primary_instance_name)
        logger.info(f"Current replica count: {current_replicas}")

        # Get metrics
        cpu_usage = get_cpu_usage(monitoring_client, project_id, primary_instance_name)
        connection_count = get_connection_count(monitoring_client, project_id, primary_instance_name)
        replication_lag = get_replication_lag(monitoring_client, project_id)

        logger.info(f"CPU Usage: {cpu_usage}%, Connections: {connection_count}, Replication Lag: {replication_lag}s")

        # Determine scaling action
        should_scale_up = (
            cpu_usage > cpu_threshold_high or 
            connection_count > connection_threshold_high or
            replication_lag > 10  # 10 seconds replication lag threshold
        )

        should_scale_down = (
            cpu_usage < cpu_threshold_low and 
            connection_count < connection_threshold_high * 0.5 and
            replication_lag < 5
        )

        # Execute scaling
        if should_scale_up and current_replicas < max_replica_count:
            new_replica_count = min(current_replicas + 1, max_replica_count)
            scale_replicas(sql_client, project_id, region, primary_instance_name, new_replica_count)
            logger.info(f"Scaled up from {current_replicas} to {new_replica_count} replicas")
            
        elif should_scale_down and current_replicas > min_replica_count:
            new_replica_count = max(current_replicas - 1, min_replica_count)
            scale_replicas(sql_client, project_id, region, primary_instance_name, new_replica_count)
            logger.info(f"Scaled down from {current_replicas} to {new_replica_count} replicas")
            
        else:
            logger.info("No scaling action needed")

    except Exception as e:
        logger.error(f"Error in autoscaling function: {str(e)}")
        raise

def get_current_replica_count(sql_client, project_id, primary_instance_name):
    """Get current number of read replicas"""
    try:
        request = sql_v1.SqlInstancesListRequest(project=project_id)
        instances = sql_client.list(request=request)
        
        replica_count = 0
        for instance in instances.items:
            if (hasattr(instance, 'master_instance_name') and 
                instance.master_instance_name and 
                primary_instance_name in instance.master_instance_name):
                replica_count += 1
                
        return replica_count
    except Exception as e:
        logger.error(f"Error getting replica count: {str(e)}")
        return 0

def get_cpu_usage(monitoring_client, project_id, instance_name):
    """Get CPU usage from Cloud Monitoring"""
    try:
        project_name = f"projects/{project_id}"
        interval = monitoring_v3.TimeInterval({
            "end_time": {"seconds": int(datetime.now().timestamp())},
            "start_time": {"seconds": int((datetime.now() - timedelta(minutes=5)).timestamp())},
        })

        filter_str = f'resource.type="cloudsql_database" AND resource.labels.database_id="{project_id}:{instance_name}" AND metric.type="cloudsql.googleapis.com/database/cpu/utilization"'
        
        request = monitoring_v3.ListTimeSeriesRequest({
            "name": project_name,
            "filter": filter_str,
            "interval": interval,
            "view": monitoring_v3.ListTimeSeriesRequest.TimeSeriesView.FULL,
        })

        results = monitoring_client.list_time_series(request=request)
        
        # Get average CPU usage
        total_cpu = 0
        count = 0
        for result in results:
            for point in result.points:
                total_cpu += point.value.double_value
                count += 1
                
        return (total_cpu / count * 100) if count > 0 else 0
        
    except Exception as e:
        logger.error(f"Error getting CPU usage: {str(e)}")
        return 0

def get_connection_count(monitoring_client, project_id, instance_name):
    """Get connection count from Cloud Monitoring"""
    try:
        project_name = f"projects/{project_id}"
        interval = monitoring_v3.TimeInterval({
            "end_time": {"seconds": int(datetime.now().timestamp())},
            "start_time": {"seconds": int((datetime.now() - timedelta(minutes=5)).timestamp())},
        })

        filter_str = f'resource.type="cloudsql_database" AND resource.labels.database_id="{project_id}:{instance_name}" AND metric.type="cloudsql.googleapis.com/database/network/connections"'
        
        request = monitoring_v3.ListTimeSeriesRequest({
            "name": project_name,
            "filter": filter_str,
            "interval": interval,
            "view": monitoring_v3.ListTimeSeriesRequest.TimeSeriesView.FULL,
        })

        results = monitoring_client.list_time_series(request=request)
        
        # Get latest connection count
        latest_connections = 0
        for result in results:
            if result.points:
                latest_connections = max(latest_connections, result.points[0].value.int64_value)
                
        return latest_connections
        
    except Exception as e:
        logger.error(f"Error getting connection count: {str(e)}")
        return 0

def get_replication_lag(monitoring_client, project_id):
    """Get replication lag from Cloud Monitoring"""
    try:
        project_name = f"projects/{project_id}"
        interval = monitoring_v3.TimeInterval({
            "end_time": {"seconds": int(datetime.now().timestamp())},
            "start_time": {"seconds": int((datetime.now() - timedelta(minutes=5)).timestamp())},
        })

        filter_str = f'resource.type="cloudsql_database" AND metric.type="cloudsql.googleapis.com/database/replication/replica_lag"'
        
        request = monitoring_v3.ListTimeSeriesRequest({
            "name": project_name,
            "filter": filter_str,
            "interval": interval,
            "view": monitoring_v3.ListTimeSeriesRequest.TimeSeriesView.FULL,
        })

        results = monitoring_client.list_time_series(request=request)
        
        # Get maximum replication lag
        max_lag = 0
        for result in results:
            for point in result.points:
                max_lag = max(max_lag, point.value.double_value)
                
        return max_lag
        
    except Exception as e:
        logger.error(f"Error getting replication lag: {str(e)}")
        return 0

def scale_replicas(sql_client, project_id, region, primary_instance_name, target_count):
    """Scale read replicas to target count"""
    try:
        current_count = get_current_replica_count(sql_client, project_id, primary_instance_name)
        
        if target_count > current_count:
            # Scale up - create new replicas
            for i in range(current_count, target_count):
                replica_name = f"{primary_instance_name}-replica-auto-{i+1}"
                create_replica(sql_client, project_id, region, primary_instance_name, replica_name)
                
        elif target_count < current_count:
            # Scale down - delete replicas
            replicas_to_delete = current_count - target_count
            delete_oldest_replicas(sql_client, project_id, primary_instance_name, replicas_to_delete)
            
    except Exception as e:
        logger.error(f"Error scaling replicas: {str(e)}")
        raise

def create_replica(sql_client, project_id, region, primary_instance_name, replica_name):
    """Create a new read replica"""
    try:
        replica_body = sql_v1.DatabaseInstance({
            "name": replica_name,
            "region": region,
            "database_version": "MYSQL_8_0",
            "master_instance_name": primary_instance_name,
            "replica_configuration": sql_v1.ReplicaConfiguration({
                "failover_target": False
            }),
            "settings": sql_v1.Settings({
                "tier": "db-n1-standard-1",
                "ip_configuration": sql_v1.IpConfiguration({
                    "ipv4_enabled": False,
                    "require_ssl": True
                })
            })
        })

        request = sql_v1.SqlInstancesInsertRequest({
            "project": project_id,
            "body": replica_body
        })

        operation = sql_client.insert(request=request)
        logger.info(f"Creating replica {replica_name}, operation: {operation.name}")
        
    except Exception as e:
        logger.error(f"Error creating replica {replica_name}: {str(e)}")
        raise

def delete_oldest_replicas(sql_client, project_id, primary_instance_name, count_to_delete):
    """Delete the oldest auto-created replicas"""
    try:
        request = sql_v1.SqlInstancesListRequest(project=project_id)
        instances = sql_client.list(request=request)
        
        # Find auto-created replicas
        auto_replicas = []
        for instance in instances.items:
            if (hasattr(instance, 'master_instance_name') and 
                instance.master_instance_name and 
                primary_instance_name in instance.master_instance_name and
                'auto' in instance.name):
                auto_replicas.append(instance)
        
        # Sort by creation time and delete oldest
        auto_replicas.sort(key=lambda x: x.create_time)
        
        for i in range(min(count_to_delete, len(auto_replicas))):
            replica_name = auto_replicas[i].name
            delete_request = sql_v1.SqlInstancesDeleteRequest({
                "project": project_id,
                "instance": replica_name
            })
            operation = sql_client.delete(request=delete_request)
            logger.info(f"Deleting replica {replica_name}, operation: {operation.name}")
            
    except Exception as e:
        logger.error(f"Error deleting replicas: {str(e)}")
        raise