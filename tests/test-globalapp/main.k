
import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1
import models.io.upbound.example.v1alpha1 as examplev1alpha1
import models.io.upbound.azurem.v1beta1 as azuremv1beta1
import models.io.upbound.azurem.cache.v1beta1 as cachev1beta1
import models.io.crossplane.helmm.v1beta1 as helmmv1beta1

_items = [
    metav1alpha1.CompositionTest{
        metadata.name = "test-globalapp-basic"
        spec = {
            assertResources: [
                # The XR
                examplev1alpha1.GlobalApp{
                    metadata.name = "blue-active"
                    metadata.namespace = "default"
                    spec = {
                        region = "West Europe"
                        primaryGeoTag = "eu"
                        hostname = "globalapp.cloud.example.com"
                        managementPolicies = ["*"]
                        autoApplyRecommendedPolicy = False
                    }
                }
                
                # Resource Group
                azuremv1beta1.ResourceGroup{
                    metadata.name = "resource-group-blue-active"
                    metadata.labels = {
                        "demo" = "gslb"
                    }
                    spec.forProvider = {
                        location = "West Europe"
                    }
                    spec.managementPolicies = ["*"]
                }
                
                # Redis Cache
                cachev1beta1.RedisCache{
                    metadata.name = "redis-cache-blue-active"
                    spec.forProvider = {
                        location = "West Europe"
                        resourceGroupNameSelector = {
                            matchControllerRef = True
                        }
                        capacity = 2
                        family = "C"
                        skuName = "Standard"
                        redisVersion = "6"
                        nonSslPortEnabled = False
                        minimumTlsVersion = "1.2"
                    }
                    spec.managementPolicies = ["*"]
                }
            ]
            compositionPath = "../../apis/globalapps/composition.yaml"
            xrPath = "../../examples/globalapp/blue-active.yaml"
            xrdPath = "../../apis/globalapps/definition.yaml"
            timeoutSeconds = 120
            validate = False
        }
    }
    metav1alpha1.CompositionTest{
        metadata.name = "test-globalapp-auto"
        spec = {
            assertResources: [
                # The XR
                examplev1alpha1.GlobalApp{
                    metadata.name = "blue-auto"
                    metadata.namespace = "demo"
                    spec = {
                        region = "East US"
                        primaryGeoTag = "us"
                        hostname = "auto-globalapp.cloud.example.com"
                        managementPolicies = ["*"]
                        autoApplyRecommendedPolicy = True
                    }
                }
                
                # Resource Group
                azuremv1beta1.ResourceGroup{
                    metadata.name = "resource-group-blue-auto"
                    metadata.labels = {
                        "demo" = "gslb"
                    }
                    spec.forProvider = {
                        location = "East US"
                    }
                    spec.managementPolicies = ["*"]
                }

                # Redis Cache
                cachev1beta1.RedisCache{
                    metadata.name = "redis-cache-blue-auto"
                    spec.forProvider = {
                        location = "East US"
                        resourceGroupNameSelector = {
                            matchControllerRef = True
                        }
                        capacity = 2
                        family = "C"
                        skuName = "Standard"
                        redisVersion = "6"
                        nonSslPortEnabled = False
                        minimumTlsVersion = "1.2"
                    }
                    spec.managementPolicies = ["*"]
                }
            ]
            compositionPath = "../../apis/globalapps/composition.yaml"
            xrPath = "../../examples/globalapp/blue-auto.yaml"
            xrdPath = "../../apis/globalapps/definition.yaml"
            timeoutSeconds = 120
            validate = False
        }
    }
]
items = _items
