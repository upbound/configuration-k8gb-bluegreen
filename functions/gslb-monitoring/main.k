oxr = option("params").oxr # observed composite resource
ocds = option("params").ocds # observed composed resources
_dxr = {
    **option("params").dxr
    status.gslb = {}
}

# Initialize default values
_recommendedPolicy = oxr.spec?.managementPolicies[0] or "*"
_policyReason = "Initializing"
_isActiveCluster = False

# Monitor health of GSLB created by application step
if "gslb-resource" in ocds:
    _gslbStatus = ocds["gslb-resource"].Resource?.status
    serviceHealth = _gslbStatus?.serviceHealth
    geoTag = _gslbStatus?.geoTag or "unknown"

    # Store geoTag in status for use by application step
    _dxr.status.gslb.geoTag = geoTag

    # Check GSLB health
    if serviceHealth:
        _unhealthyDomains = [k for k, v in serviceHealth if v != "Healthy"]
        _gslbHealthy = len(_unhealthyDomains) == 0
        if _gslbHealthy:
            _dxr.status.gslb.healthy = "All {} GSLB domains are healthy".format(len(serviceHealth))
        else:
            _dxr.status.gslb.healthy = "GSLB UNHEALTHY: {} ({}/{} unhealthy)".format(_unhealthyDomains, len(_unhealthyDomains), len(serviceHealth))
    else:
        _gslbHealthy = False
        _dxr.status.gslb.healthy = "No GSLB serviceHealth data available"

    # Check if we are the active cluster from GSLB perspective
    _hostname = oxr.spec?.hostname or "globalapp.cloud.example.com"
    _healthyRecords = _gslbStatus?.healthyRecords?[_hostname] or []
    _exposedIps = _gslbStatus?.loadBalancer?.exposedIps or []
    _isActiveCluster = len(_healthyRecords) > 0 and len(_exposedIps) > 0 and _healthyRecords == _exposedIps

    # Simple GSLB-based policy decision
    if _gslbHealthy and _isActiveCluster:
        _recommendedPolicy = "*"
        _policyReason = "GSLB healthy and cluster is active"
    else:
        _recommendedPolicy = "Observe"
        _policyReason = "GSLB unhealthy or traffic routed elsewhere"

    # Debug info
    _dxr.status.gslb.debugHealthyRecords = str(_healthyRecords)
    _dxr.status.gslb.debugExposedIps = str(_exposedIps)
else:
    _dxr.status.gslb.healthy = "GSLB resource not found"
    _policyReason = "GSLB not available"

# Always set these fields
_dxr.status.gslb.isActiveCluster = _isActiveCluster
_dxr.status.gslb.recommendedPolicy = _recommendedPolicy
_dxr.status.gslb.policyReason = _policyReason

# Add auto-apply status
_autoApplyEnabled = oxr.spec?.autoApplyRecommendedPolicy or False
_currentManualPolicy = oxr.spec?.managementPolicies[0] if oxr.spec?.managementPolicies else "*"
_dxr.status.gslb.autoApplyEnabled = _autoApplyEnabled
if _autoApplyEnabled:
    _dxr.status.gslb.appliedPolicy = _recommendedPolicy
    _dxr.status.gslb.autoApplyStatus = "Policy automatically applied: {}".format(_recommendedPolicy)
else:
    _dxr.status.gslb.appliedPolicy = _currentManualPolicy
    _dxr.status.gslb.autoApplyStatus = "Manual policy used: {}".format(_currentManualPolicy)

items = [_dxr]
