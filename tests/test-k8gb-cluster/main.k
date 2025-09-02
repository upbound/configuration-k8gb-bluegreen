
import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1
import models.io.upbound.example.v1alpha1 as examplev1alpha1
import models.io.crossplane.helm.v1beta1 as helmv1beta1

_items = [
    metav1alpha1.CompositionTest{
        metadata.name = "test-k8gb-eu-cluster"
        spec = {
            assertResources: [
                # The XR
                examplev1alpha1.K8gbCluster{
                    metadata.name = "eu-cluster"
                    spec = {
                        version = "v0.15.0"
                        geoTag = "eu"
                        externalClustersGeoTags = "eu,us"
                        dnsZones = [
                            {
                                parentZone = "example.com"
                                loadBalancedZone = "cloud.example.com"
                                negTTL = 30
                            }
                        ]
                        edgeDNSServers = ["1.1.1.1"]
                        logLevel = "info"
                    }
                }
                
                # Helm Release for k8gb
                helmv1beta1.Release{
                    metadata.name = "k8gb-eu-cluster"
                    spec.forProvider = {
                        chart = {
                            name = "k8gb"
                            repository = "https://www.k8gb.io"
                            version = "v0.15.0"
                        }
                        namespace = "k8gb"
                        wait = True
                        waitTimeout = "600s"
                    }
                }
            ]
            compositionPath = "../../apis/k8gbclusters/composition.yaml"
            xrPath = "../../examples/k8gb-cluster/eu-cluster.yaml"
            xrdPath = "../../apis/k8gbclusters/definition.yaml"
            timeoutSeconds = 120
            validate = False
        }
    }
]

items = _items