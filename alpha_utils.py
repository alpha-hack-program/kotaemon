from kubernetes import client, config as k8s_config

# Load in-cluster Kubernetes configuration but if it fails, load local configuration
try:
    k8s_config.load_incluster_config()
except k8s_config.config_exception.ConfigException:
    k8s_config.load_kube_config()

# Get prediction URL by name and namespace
def get_predictor_url(namespace, predictor_name):
    api_instance = client.CustomObjectsApi()
    try:
        predictor = api_instance.get_namespaced_custom_object(
            group="serving.kserve.io",
            version="v1beta1",
            namespace=namespace,
            plural="inferenceservices",
            name=predictor_name
        )
        return f"{predictor['status']['url']}"
    except Exception as e:
        print(f"Error retrieving predictor {predictor_name} in namespace {namespace}: {e}")
        return None