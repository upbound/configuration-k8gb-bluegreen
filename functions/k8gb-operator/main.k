
import models.io.crossplane.helm.v1beta1 as helmv1beta1

oxr = option("params").oxr # observed composite resource
ocds = option("params").ocds # observed composed resources
_dxr = {
    **option("params").dxr
    status.installation = {}
}

_metadata = lambda name: str -> any {
    { 
        annotations = { "krm.kcl.dev/composition-resource-name" = name }
        name = name + "-" + oxr.metadata.name
    }
}

# Install nginx ingress controller with k8gb-specific configuration
nginxIngress = helmv1beta1.Release {
    metadata = {
        **_metadata("nginx-ingress")
        name = "nginx-ingress-" + oxr.metadata.name
    }
    spec = {
        forProvider = {
            chart = {
                name = "ingress-nginx"
                repository = "https://kubernetes.github.io/ingress-nginx"
                version = "4.0.15"
            }
            namespace = "k8gb"
            values = {
                controller = {
                    admissionWebhooks = {
                        enabled = False
                        patch = {
                            enabled = False
                        }
                    }
                    hostNetwork = True
                    publishService = {
                        enabled = False
                    }
                    daemonset = {
                        useHostPort = False
                        hostPorts = {
                            http = 80
                            https = 443
                        }
                    }
                    kind = "DaemonSet"
                    service = {
                        enabled = False
                    }
                }
                udp = {
                    "53" = "k8gb/k8gb-coredns:53"
                }
            }
            wait = True
            waitTimeout = "600s"
        }
    }
}

# Install k8gb operator using Helm
k8gbOperator = helmv1beta1.Release {
    metadata = _metadata("k8gb")
    spec = {
        forProvider = {
            chart = {
                name = "k8gb"
                repository = "https://www.k8gb.io"
                version = oxr.spec.version
            }
            namespace = "k8gb"
            values = {
                k8gb = {
                    deployCrds = True
                    deployRbac = True
                    clusterGeoTag = oxr.spec.geoTag
                    extGslbClustersGeoTags = oxr.spec.externalClustersGeoTags
                    dnsZones = oxr.spec.dnsZones
                    edgeDNSServers = oxr.spec.edgeDNSServers
                    log = {
                        format = "simple"
                        level = oxr.spec.logLevel
                    }
                    reconcileRequeueSeconds = 30
                    nsRecordTTL = 30
                    metricsAddress = "0.0.0.0:8080"
                }
                # Enable external-dns (required for k8gb)
                extdns = {
                    enabled = True
                    interval = "20s"
                    labelFilter = "k8gb.absa.oss/dnstype=extdns"
                    logLevel = "debug"
                    policy = "sync"
                    txtOwnerId = "k8gb-" + oxr.spec.geoTag
                    txtPrefix = "k8gb-" + oxr.spec.geoTag + "-"
                }
            }
            wait = True
            waitTimeout = "600s"
        }
    }
}

# Simple status update
if "k8gb" in ocds and ocds["k8gb"].Resource?.status?.atProvider?.state == "deployed":
    _dxr.status.installation.ready = True
else:
    _dxr.status.installation.ready = False

# Initial ingress for k8gb IP discovery (required when coredns.serviceType=ClusterIP)
_initIngress = {
    apiVersion = "networking.k8s.io/v1"
    kind = "Ingress"
    metadata = {
        **_metadata("init-ingress")
        name = "init-ingress-" + oxr.metadata.name
        namespace = "k8gb"
        labels = {
            app = "init-ingress"
            "k8gb.io/ip-source" = "true"
        }
    }
    spec = {
        ingressClassName = "nginx"
        rules = [
            {
                host = "init." + oxr.spec.dnsZones[0].loadBalancedZone
                http = {
                    paths = [
                        {
                            backend = {
                                service = {
                                    name = "k8gb-coredns"
                                    port = {
                                        name = "udp-5353"
                                    }
                                }
                            }
                            path = "/"
                            pathType = "Prefix"
                        }
                    ]
                }
            }
        ]
    }
}

# Check if init-ingress has external IP and mark as ready
if "init-ingress" in ocds:
    _observedIngress = ocds["init-ingress"].Resource
    _hasExternalIP = len(_observedIngress?.status?.loadBalancer?.ingress or []) > 0
    if _hasExternalIP:
        _initIngress.metadata.annotations["krm.kcl.dev/ready"] = "True"

items = [nginxIngress, k8gbOperator, _initIngress, _dxr]
