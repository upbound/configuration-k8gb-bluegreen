
import models.io.upbound.azurem.cache.v1beta1 as cachev1beta1
import models.io.upbound.azurem.v1beta1 as azuremv1beta1

oxr = option("params").oxr # observed composite resource
ocds = option("params").ocds # observed composed resources
_dxr = {
    **option("params").dxr
    status.infrastructure = {}
}

_metadata = lambda name: str -> any {
    {
        annotations = { "krm.kcl.dev/composition-resource-name" = name }
        name = name + "-" + oxr.metadata.name
    }
}

# Determine which management policy to use
_autoApply = oxr.spec?.autoApplyRecommendedPolicy or False
_manualPolicy = oxr.spec?.managementPolicies or ["*"]
_recommendedFromStatus = oxr.status?.gslb?.recommendedPolicy or "*"
_finalPolicy = [_recommendedFromStatus] if _autoApply else _manualPolicy

# Azure Resource Group
resourceGroup = azuremv1beta1.ResourceGroup {
    metadata = {
        **_metadata("resource-group")
        annotations = {
            **_metadata("resource-group").annotations
            "crossplane.io/external-name" = "gslb-demo-rg-" + oxr.metadata.name
        }
        labels = {
            "demo" = "gslb"
        }
    }
    spec = {
        managementPolicies = _finalPolicy
        forProvider = {
            location = oxr.spec?.region or "West US"
        }
    }
}

# Azure Redis Cache
redisCache = cachev1beta1.RedisCache {
    metadata = {
        **_metadata("redis-cache")
        annotations = {
            **_metadata("redis-cache").annotations
            "crossplane.io/external-name" = "redis-cache-" + oxr.metadata.name
        }
    }
    spec = {
        managementPolicies = _finalPolicy
        forProvider = {
            location = oxr.spec?.region or "West US"
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
    }
}

# Update status based on infrastructure readiness
if "resource-group" in ocds:
    _rgReadyCondition = [c for c in ocds["resource-group"].Resource?.status?.conditions or [] if c.type == "Ready" and c.status == "True"]
    if len(_rgReadyCondition) > 0:
        _dxr.status.infrastructure.resourceGroup = "Resource group ready"
    else:
        _dxr.status.infrastructure.resourceGroup = "Resource group provisioning"
else:
    _dxr.status.infrastructure.resourceGroup = "Resource group not found"

if "redis-cache" in ocds:
    _redisReadyCondition = [c for c in ocds["redis-cache"].Resource?.status?.conditions or [] if c.type == "Ready" and c.status == "True"]
    if len(_redisReadyCondition) > 0:
        _dxr.status.infrastructure.redis = "Redis cache ready"
    else:
        _dxr.status.infrastructure.redis = "Redis cache provisioning"
else:
    _dxr.status.infrastructure.redis = "Redis cache not found"

items = [resourceGroup, redisCache, _dxr]
