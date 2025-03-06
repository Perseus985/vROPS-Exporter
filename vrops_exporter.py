import time
import argparse
import logging
import os
import urllib3
import json
import re
import requests
import threading
import queue
from concurrent.futures import ThreadPoolExecutor
from prometheus_client import start_http_server, Gauge, Counter, Info, REGISTRY
from requests.packages.urllib3.exceptions import InsecureRequestWarning

# Disable SSL warnings
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
requests.packages.urllib3.disable_warnings(InsecureRequestWarning)

# Set up logging
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO
)
logger = logging.getLogger('vrops-exporter')

class VROpsCollector:
    """
    Collector for VMware vRealize Operations Manager metrics.
    Fetches metrics from vROps API and exposes them for Prometheus.
    Implements batching to efficiently handle large metric volumes.
    """
    
    def __init__(self, host, username, password, port=443, verify_ssl=False, 
                 resource_kinds=None, metrics_allowlist=None, labels_allowlist=None, 
                 collection_interval=300, batch_size=100, worker_threads=5,
                 resource_batch_size=50, metric_batch_size=1000):
        """
        Initialize the collector with vROps connection parameters.
        
        Args:
            host: vROps hostname or IP
            username: vROps username
            password: vROps password
            port: vROps API port (default: 443)
            verify_ssl: Whether to verify SSL certificates (default: False)
            resource_kinds: List of resource kinds to collect (default: None for all)
            metrics_allowlist: List of metric names to include (default: None for all)
            labels_allowlist: List of property names to use as labels (default: None)
            collection_interval: Time between collections in seconds (default: 300)
            batch_size: Number of resources to process in a batch (default: 100)
            worker_threads: Number of worker threads for parallel processing (default: 5)
            resource_batch_size: Number of resources to request in a batch from API (default: 50)
            metric_batch_size: Number of metrics to request in a batch from API (default: 1000)
        """
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.verify_ssl = verify_ssl
        self.base_url = f"https://{host}:{port}/suite-api"
        self.token = None
        self.token_expiry = 0
        self.resource_kinds = resource_kinds or []
        self.metrics_allowlist = metrics_allowlist or []
        self.labels_allowlist = labels_allowlist or ["name", "adapterKindKey", "resourceKindKey"]
        self.collection_interval = collection_interval
        self.batch_size = batch_size
        self.worker_threads = worker_threads
        self.resource_batch_size = resource_batch_size
        self.metric_batch_size = metric_batch_size
        
        # Store metrics to avoid recreating them
        self.metrics = {}
        self.resource_cache = {}
        self.metric_key_cache = {}
        
        # For thread-safe operations
        self.metrics_lock = threading.RLock()
        self.token_lock = threading.RLock()
        
        # Collector info
        self.collector_info = Info('vrops_collector', 'Information about the vROps collector')
        self.collector_info.info({
            'host': host,
            'version': '0.2.0',
        })
        
        # Metrics for the collector itself
        self.collector_up = Gauge('vrops_collector_up', 'Whether the collector is up (1) or down (0)')
        self.collector_scrape_duration = Gauge('vrops_collector_scrape_duration_seconds', 
                                             'Time spent collecting metrics from vROps')
        self.collector_errors = Counter('vrops_collector_errors_total', 
                                      'Total number of errors encountered during collection')
        self.resources_collected = Gauge('vrops_resources_collected', 
                                       'Number of resources collected in the last scrape')
        self.metrics_collected = Gauge('vrops_metrics_collected', 
                                     'Number of metrics collected in the last scrape')
        self.batch_duration = Gauge('vrops_batch_duration_seconds',
                                  'Time spent processing a batch of resources')
        self.api_requests = Counter('vrops_api_requests_total',
                                  'Total number of API requests made to vROps')
        self.api_errors = Counter('vrops_api_errors_total',
                                'Total number of API errors encountered')
        
    def authenticate(self):
        """Authenticate to vROps API and get a token."""
        now = time.time()
        
        with self.token_lock:
            # Reuse token if it's still valid
            if self.token and now < self.token_expiry:
                return
                
            auth_url = f"{self.base_url}/api/auth/token/acquire"
            auth_payload = {
                "username": self.username,
                "password": self.password
            }
            
            try:
                response = requests.post(
                    auth_url, 
                    json=auth_payload, 
                    verify=self.verify_ssl,
                    headers={"Content-Type": "application/json", "Accept": "application/json"}
                )
                self.api_requests.inc()
                response.raise_for_status()
                
                data = response.json()
                self.token = data.get("token")
                # Set expiry to 10 minutes before actual expiry to be safe
                # vROps tokens typically last 30 minutes
                self.token_expiry = now + 20 * 60  
                logger.info("Successfully authenticated to vROps API")
                
            except requests.exceptions.RequestException as e:
                logger.error(f"Authentication failed: {str(e)}")
                self.collector_errors.inc()
                self.api_errors.inc()
                self.token = None
                raise
    
    def get_headers(self):
        """Get HTTP headers with authentication token."""
        self.authenticate()
        return {
            "Authorization": f"vRealizeOpsToken {self.token}",
            "Accept": "application/json",
            "Content-Type": "application/json"
        }
    
    def get_adapter_kinds(self):
        """Get the list of adapter kinds from vROps."""
        try:
            response = requests.get(
                f"{self.base_url}/api/adapterkinds",
                headers=self.get_headers(),
                verify=self.verify_ssl
            )
            self.api_requests.inc()
            response.raise_for_status()
            return response.json().get("adapterKind", [])
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to get adapter kinds: {str(e)}")
            self.collector_errors.inc()
            self.api_errors.inc()
            return []
    
    def get_resources(self, resource_kinds=None):
        """
        Get resources of specified kinds from vROps in batches.
        
        Args:
            resource_kinds: List of resource kinds to filter by (default: None for all)
        
        Returns:
            Generator yielding batches of resources
        """
        resource_kinds = resource_kinds or self.resource_kinds
        page = 0
        
        while True:
            try:
                # Add resource kind filter if specified
                if resource_kinds:
                    query_url = f"{self.base_url}/api/resources/query"
                    payload = {
                        "resourceKind": resource_kinds,
                        "page": page,
                        "pageSize": self.resource_batch_size
                    }
                    response = requests.post(
                        query_url,
                        json=payload,
                        headers=self.get_headers(),
                        verify=self.verify_ssl,
                        timeout=60  # Add a timeout to prevent hanging
                    )
                else:
                    query_url = f"{self.base_url}/api/resources"
                    query_params = {
                        "page": page,
                        "pageSize": self.resource_batch_size
                    }
                    response = requests.get(
                        query_url,
                        params=query_params,
                        headers=self.get_headers(),
                        verify=self.verify_ssl,
                        timeout=60  # Add a timeout to prevent hanging
                    )
                
                self.api_requests.inc()
                response.raise_for_status()
                data = response.json()
                
                # Get pagination info
                page_info = data.get("pageInfo", {})
                total_pages = page_info.get("totalPages", 1)
                
                # Get resources
                resources = data.get("resourceList", [])
                if not resources:
                    break
                
                logger.info(f"Retrieved {len(resources)} resources from vROps (page {page+1}/{total_pages})")
                yield resources
                
                page += 1
                if page >= total_pages:
                    break
                    
            except requests.exceptions.RequestException as e:
                logger.error(f"Failed to get resources (page {page}): {str(e)}")
                self.collector_errors.inc()
                self.api_errors.inc()
                # Sleep briefly before continuing to next page
                time.sleep(2)
                # If we've had too many errors, break out
                if page > 5:
                    break
    
    def get_resource_metrics(self, resource_id):
        """
        Get metrics for a specific resource.
        
        Args:
            resource_id: The UUID of the resource
        
        Returns:
            List of metrics for the resource
        """
        try:
            # First get available metrics for this resource
            stats_url = f"{self.base_url}/api/resources/{resource_id}/stats"
            response = requests.get(
                stats_url,
                headers=self.get_headers(),
                verify=self.verify_ssl,
                timeout=60  # Add a timeout to prevent hanging
            )
            self.api_requests.inc()
            response.raise_for_status()
            
            # Extract available stat keys
            data = response.json()
            return data.get("values", [])
            
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to get metrics for resource {resource_id}: {str(e)}")
            self.collector_errors.inc()
            self.api_errors.inc()
            return []
    
    def get_resource_properties(self, resource_id):
        """
        Get properties for a specific resource.
        
        Args:
            resource_id: The UUID of the resource
        
        Returns:
            Dictionary of properties for the resource
        """
        # Check cache first
        if resource_id in self.resource_cache:
            return self.resource_cache[resource_id]
            
        properties = {}
        try:
            props_url = f"{self.base_url}/api/resources/{resource_id}/properties"
            response = requests.get(
                props_url,
                headers=self.get_headers(),
                verify=self.verify_ssl,
                timeout=30  # Add a timeout to prevent hanging
            )
            self.api_requests.inc()
            response.raise_for_status()
            
            # Convert properties to a dictionary
            for prop in response.json().get("property", []):
                name = prop.get("name", "")
                value = prop.get("value", "")
                if name in self.labels_allowlist:
                    # Clean the property value to be usable as a Prometheus label
                    if value:
                        # Replace non-alphanumeric chars with underscores
                        clean_value = re.sub(r'[^a-zA-Z0-9_]', '_', str(value))
                        # Ensure it doesn't start with a number
                        if clean_value and clean_value[0].isdigit():
                            clean_value = f"x{clean_value}"
                        properties[name] = clean_value
            
            # Cache the result
            self.resource_cache[resource_id] = properties
            return properties
            
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to get properties for resource {resource_id}: {str(e)}")
            self.collector_errors.inc()
            self.api_errors.inc()
            return properties
    
    def sanitize_metric_name(self, name):
        """
        Sanitize a metric name to be compatible with Prometheus.
        
        Args:
            name: The original metric name
        
        Returns:
            Sanitized metric name
        """
        # Check cache first
        if name in self.metric_key_cache:
            return self.metric_key_cache[name]
            
        # Replace any non-alphanumeric characters with underscores
        sanitized = re.sub(r'[^a-zA-Z0-9_]', '_', name)
        # Ensure name starts with a letter
        if sanitized and sanitized[0].isdigit():
            sanitized = f"x{sanitized}"
        # Replace double underscores with single
        sanitized = re.sub(r'__+', '_', sanitized)
        # Remove leading/trailing underscores
        sanitized = sanitized.strip('_')
        # Lowercase for consistency
        sanitized = f"vrops_{sanitized}".lower()
        
        # Cache the result
        self.metric_key_cache[name] = sanitized
        return sanitized
    
    def process_resource(self, resource):
        """
        Process a single resource and extract its metrics.
        
        Args:
            resource: Resource object from vROps API
        
        Returns:
            Number of metrics processed
        """
        metrics_count = 0
        resource_id = resource.get("identifier")
        resource_name = resource.get("resourceKey", {}).get("name", "unknown")
        
        # Skip if no identifier
        if not resource_id:
            return 0
        
        # Get resource properties for labels
        properties = self.get_resource_properties(resource_id)
        
        # Get metrics for this resource
        metrics = self.get_resource_metrics(resource_id)
        
        for metric in metrics:
            stat_key = metric.get("statKey", {}).get("key", "")
            value = metric.get("values", [{}])[0].get("value", None)
            
            # Skip if no value or key, or if key is not in allowlist (if specified)
            if value is None or not stat_key:
                continue
            
            if self.metrics_allowlist and stat_key not in self.metrics_allowlist:
                continue
            
            # Convert stat key to a valid Prometheus metric name
            metric_name = self.sanitize_metric_name(stat_key)
            
            # Prepare labels
            labels = {"resource_id": resource_id, "resource_name": resource_name}
            labels.update(properties)
            
            # Create metric if it doesn't exist
            with self.metrics_lock:
                if metric_name not in self.metrics:
                    self.metrics[metric_name] = Gauge(
                        metric_name,
                        f"vROps metric: {stat_key}",
                        list(labels.keys())
                    )
            
            # Set metric value with labels
            try:
                self.metrics[metric_name].labels(**labels).set(float(value))
                metrics_count += 1
            except (ValueError, TypeError) as e:
                logger.warning(f"Could not convert value '{value}' to float for metric {metric_name}: {e}")
        
        return metrics_count
    
    def process_resource_batch(self, resources):
        """
        Process a batch of resources.
        
        Args:
            resources: List of resources from vROps API
        
        Returns:
            Number of metrics processed
        """
        batch_start = time.time()
        metrics_count = 0
        resources_processed = 0
        
        # Create a thread pool to process resources in parallel
        with ThreadPoolExecutor(max_workers=self.worker_threads) as executor:
            # Submit all resources to the thread pool
            future_to_resource = {
                executor.submit(self.process_resource, resource): resource
                for resource in resources
            }
            
            # Process the results as they complete
            for future in future_to_resource:
                try:
                    metrics_count += future.result()
                    resources_processed += 1
                except Exception as e:
                    logger.error(f"Error processing resource: {str(e)}")
                    self.collector_errors.inc()
        
        batch_duration = time.time() - batch_start
        self.batch_duration.set(batch_duration)
        logger.info(f"Processed batch of {resources_processed} resources with {metrics_count} metrics in {batch_duration:.2f} seconds")
        
        return metrics_count, resources_processed
    
    def collect_metrics(self):
        """
        Collect metrics from vROps and expose them as Prometheus metrics.
        Processes resources in batches to manage memory usage.
        """
        start_time = time.time()
        total_resources = 0
        total_metrics = 0
        
        try:
            self.collector_up.set(1)
            
            # Clear resource cache to free memory
            self.resource_cache.clear()
            
            # Get resources in batches
            for resource_batch in self.get_resources():
                metrics_count, resources_processed = self.process_resource_batch(resource_batch)
                
                total_metrics += metrics_count
                total_resources += resources_processed
                
                # Check if we've been running too long and should stop
                if time.time() - start_time > self.collection_interval * 0.8:
                    logger.warning("Collection taking too long, stopping early")
                    break
            
            self.resources_collected.set(total_resources)
            self.metrics_collected.set(total_metrics)
            
        except Exception as e:
            logger.error(f"Error collecting metrics: {str(e)}")
            self.collector_errors.inc()
            self.collector_up.set(0)
        finally:
            collection_time = time.time() - start_time
            self.collector_scrape_duration.set(collection_time)
            logger.info(f"Collected {total_metrics} metrics from {total_resources} resources in {collection_time:.2f} seconds")
    
    def run_collector(self):
        """Run the collector continuously."""
        while True:
            try:
                self.collect_metrics()
                # Sleep for the interval, but subtract the time it took to collect
                collection_duration = self.collector_scrape_duration._value.get()
                sleep_time = max(10, self.collection_interval - collection_duration)
                logger.info(f"Sleeping for {sleep_time:.2f} seconds before next collection")
                time.sleep(sleep_time)
            except Exception as e:
                logger.error(f"Collector error: {str(e)}")
                time.sleep(60)  # Wait a bit before retrying

def parse_args():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description='vROps Prometheus Exporter')
    parser.add_argument('--host', required=True, help='vROps hostname or IP')
    parser.add_argument('--username', required=True, help='vROps username')
    parser.add_argument('--password', required=True, help='vROps password')
    parser.add_argument('--port', type=int, default=443, help='vROps API port (default: 443)')
    parser.add_argument('--exporter-port', type=int, default=9000, help='Port to expose Prometheus metrics on (default: 9000)')
    parser.add_argument('--no-verify-ssl', action='store_true', help='Disable SSL verification')
    parser.add_argument('--resource-kinds', nargs='+', help='Resource kinds to collect (default: all)')
    parser.add_argument('--metrics-file', help='File containing list of metrics to collect (one per line)')
    parser.add_argument('--labels-file', help='File containing list of properties to use as labels (one per line)')
    parser.add_argument('--interval', type=int, default=300, help='Collection interval in seconds (default: 300)')
    parser.add_argument('--log-level', default='INFO', choices=['DEBUG', 'INFO', 'WARNING', 'ERROR'], 
                        help='Log level (default: INFO)')
    parser.add_argument('--batch-size', type=int, default=100, 
                        help='Number of resources to process in a batch (default: 100)')
    parser.add_argument('--worker-threads', type=int, default=5, 
                        help='Number of worker threads for parallel processing (default: 5)')
    parser.add_argument('--resource-batch-size', type=int, default=50,
                        help='Number of resources to request in a batch from API (default: 50)')
    parser.add_argument('--metric-batch-size', type=int, default=1000,
                        help='Number of metrics to request in a batch from API (default: 1000)')
    return parser.parse_args()

def main():
    """Main entry point."""
    args = parse_args()
    
    # Set log level
    logger.setLevel(getattr(logging, args.log_level))
    
    # Load metrics allowlist if specified
    metrics_allowlist = None
    if args.metrics_file and os.path.exists(args.metrics_file):
        with open(args.metrics_file, 'r') as f:
            metrics_allowlist = [line.strip() for line in f if line.strip()]
    
    # Load labels allowlist if specified
    labels_allowlist = None
    if args.labels_file and os.path.exists(args.labels_file):
        with open(args.labels_file, 'r') as f:
            labels_allowlist = [line.strip() for line in f if line.strip()]
    
    # Start HTTP server for Prometheus
    start_http_server(args.exporter_port)
    logger.info(f"Prometheus metrics available on port {args.exporter_port}")
    
    # Create and run collector
    collector = VROpsCollector(
        host=args.host,
        username=args.username,
        password=args.password,
        port=args.port,
        verify_ssl=not args.no_verify_ssl,
        resource_kinds=args.resource_kinds,
        metrics_allowlist=metrics_allowlist,
        labels_allowlist=labels_allowlist,
        collection_interval=args.interval,
        batch_size=args.batch_size,
        worker_threads=args.worker_threads,
        resource_batch_size=args.resource_batch_size,
        metric_batch_size=args.metric_batch_size
    )
    
    try:
        collector.run_collector()
    except KeyboardInterrupt:
        logger.info("Exiting...")

if __name__ == "__main__":
    main()