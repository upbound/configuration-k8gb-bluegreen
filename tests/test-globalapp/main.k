
import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1
import models.io.upbound.example.v1alpha1 as examplev1alpha1
import models.io.upbound.azurem.v1beta1 as azuremv1beta1
import models.io.upbound.azurem.cache.v1beta1 as cachev1beta1
import models.io.crossplane.helmm.v1beta1 as helmmv1beta1

_items = [
    metav1alpha1.CompositionTest{
        metadata.name = "test-globalapp-auto"
        spec = {
            assertResources: [
                # The XR
                examplev1alpha1.GlobalApp{
                    metadata.name = "blue-green"
                    metadata.namespace = "default"
                    metadata.annotations = {
                        location = "eu"
                        environment = "blue"
                    }
                    spec = {
                        region = "West Europe"
                        primaryGeoTag = "eu"
                        hostname = "globalapp.cloud.example.com"
                        managementPolicies = ["*"]
                        autoApplyRecommendedPolicy = True
                    }
                }

                # Resource Group
                azuremv1beta1.ResourceGroup{
                    metadata.name = "resource-group-blue-green"
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
                    metadata.name = "redis-cache-blue-green"
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
        metadata.name = "test-globalapp-manual"
        spec = {
            assertResources: [
                # The XR
                examplev1alpha1.GlobalApp{
                    metadata.name = "blue-green"
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
                    metadata.name = "resource-group-blue-green"
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
                    metadata.name = "redis-cache-blue-green"
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
            xrPath = "../../examples/globalapp/blue-manual.yaml"
            xrdPath = "../../apis/globalapps/definition.yaml"
            timeoutSeconds = 120
            validate = False
        }
    }
]
items = _items
