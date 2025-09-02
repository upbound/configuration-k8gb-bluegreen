
import models.io.crossplane.helmm.v1beta1 as helmmv1beta1

oxr = option("params").oxr # observed composite resource
ocds = option("params").ocds # observed composed resources
_dxr = {
    **option("params").dxr
    status.application = {}
}

_metadata = lambda name: str -> any {
    {
        annotations = { "krm.kcl.dev/composition-resource-name" = name }
        name = name + "-" + oxr.metadata.name
    }
}

# Get Redis connection string if available
_redisHost = ""
_redisReady = False
if "redis-cache" in ocds:
    _redisHost = ocds["redis-cache"].Resource?.status?.atProvider?.hostname or ""
    _redisReady = _redisHost != ""

_items = []

# Only create Podinfo when Redis hostname is available
if _redisReady:
    podinfo = helmmv1beta1.Release {
        metadata = _metadata("podinfo")
        spec = {
            forProvider = {
                chart = {
                    name = "podinfo"
                    repository = "https://stefanprodan.github.io/podinfo"
                    version = "6.5.4"
                }
                values = {
                    ingress = {
                        enabled = True
                        className = "nginx"
                        hosts = [
                            {
                                host = oxr.spec?.hostname or "globalapp.cloud.example.com"
                                paths = [
                                    {
                                        path = "/"
                                        pathType = "Prefix"
                                    }
                                ]
                            }
                        ]
                        additionalLabels = {
                            "gslb" = "failover-ingress"
                        }
                    }
                    cache = "tcp://{}:6380".format(_redisHost)
                    ui.message = "Region: {}".format(oxr.status?.gslb?.geoTag or "unknown")
                }
            }
        }
    }

    # GSLB for traffic management
    _gslb = {
        apiVersion = "k8gb.absa.oss/v1beta1"
        kind = "Gslb"
        metadata = {
            **_metadata("gslb-resource")
            name = "failover-ingress-" + oxr.metadata.name
            namespace = oxr.metadata.namespace
        }
        spec = {
            strategy = {
                type = "failover"
                primaryGeoTag = oxr.spec?.primaryGeoTag or "eu"
            }
            resourceRef = {
                apiVersion = "networking.k8s.io/v1"
                kind = "Ingress"
                matchLabels = {
                    "gslb" = "failover-ingress"
                }
            }
        }
    }

    # Check if GSLB is healthy and mark as ready
    if "gslb-resource" in ocds:
        _observedGslb = ocds["gslb-resource"].Resource
        _serviceHealth = _observedGslb?.status?.serviceHealth or {}
        if _serviceHealth:
            _unhealthyDomains = [k for k, v in _serviceHealth if v != "Healthy"]
            _gslbHealthy = len(_unhealthyDomains) == 0
            if _gslbHealthy:
                _gslb.metadata.annotations["krm.kcl.dev/ready"] = "True"

    _items += [podinfo, _gslb]

# Update status based on Redis, Podinfo and GSLB state
if not _redisReady:
    _dxr.status.application.podinfo = "Waiting for Redis hostname"
    _dxr.status.application.gslb = "Waiting for application deployment"
elif "podinfo" in ocds and "gslb-resource" in ocds:
    if ocds["podinfo"].Resource?.status?.atProvider?.state == "deployed":
        _dxr.status.application.podinfo = "Podinfo deployed with Redis: {}".format(_redisHost)
    else:
        _dxr.status.application.podinfo = "Podinfo deploying with Redis: {}".format(_redisHost)
    _dxr.status.application.gslb = "GSLB resource created"
elif "podinfo" in ocds:
    _dxr.status.application.podinfo = "Podinfo ready, creating GSLB"
    _dxr.status.application.gslb = "Creating GSLB resource"
else:
    _dxr.status.application.podinfo = "Creating Podinfo with Redis: {}".format(_redisHost)
    _dxr.status.application.gslb = "Waiting for Podinfo"

_items += [_dxr]
items = _items
