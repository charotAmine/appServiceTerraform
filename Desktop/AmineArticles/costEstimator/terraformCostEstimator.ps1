using namespace System.Net

param($Request, $TriggerMetadata)
function Get-DefaultInformation($serviceType, $serviceObject, $serviceProperties)
{
    $skuPropertyName = ($serviceProperties | Select -ExpandProperty $serviceType).skuName
    $skuNameP = $skuPropertyName -split ";"
    $j = 0
    foreach ($skuName in $skuNameP)
    {
        $tmp = $sku
        $skuNameProperties = $skuName.split("-")
        $first = $skuNameProperties[0]
        $sku = $serviceObject.$first
        for ($i = 1; $i -lt $skuNameProperties.Length; $i++) {
            $other = $skuNameProperties[$i]
            $sku = $sku.$other
        }
        $sku = $sku.ToLower()
        $realSku = ($serviceProperties | Select -ExpandProperty $serviceType).$sku
        if($realSku -eq $null)
        {
            $TextInfo = (Get-Culture).TextInfo
            $sku = $TextInfo.ToTitleCase($sku)
        }else{
            $sku = $realSku
        }
        if($j -gt 0){
            $sku = $tmp + " " + $sku
        }
        $j++
    }
    return $sku
}
function Get-DefaultUrl($serviceType, $serviceObject, $serviceProperties) {
    $sku = Get-DefaultInformation $serviceType $serviceObject $serviceProperties
    $url = "https://prices.azure.com/api/retail/prices?" + '$filter=' + "serviceName eq '$serviceType' and armRegionName eq '$($serviceObject.location)' and skuName eq '$($sku)'"
    return $url
}

function Get-StorageUrl($serviceType, $serviceObject, $serviceProperties){
    $sku = Get-DefaultInformation $serviceType $serviceObject $serviceProperties
    $productName = $serviceObject.account_kind
    switch($productName){
        "StorageV2" {
            $accessTier = $serviceObject.access_tier
            if($accessTier -eq $null)
            {
                $accessTier = "Hot"
            }
            $sku =  $accessTier + " " + $sku
            $product = "General Block Blob v2"
        }
        "Storage" {
            $sku = "Standard " + $sku
            $product = "General Block Blob"
        }
        $null {
            $accessTier = $serviceObject.access_tier
            if($accessTier -eq $null)
            {
                $accessTier = "Hot"
            }
            $sku = $accessTier + " " + $sku
            $product = "General Block Blob v2"
        }
    }
    
    $url = "https://prices.azure.com/api/retail/prices?" + '$filter=' + "serviceName eq '$serviceType' and armRegionName eq '$($serviceObject.location)' and skuName eq '$($sku)' and productName eq '$($product)'"
    return $url
}

function Get-ServicePrice($url) {
    $list = New-Object System.Collections.ArrayList
    $response = (iwr $url).Content | ConvertFrom-Json
    $pricing = $response.items | Group-Object -Property 'meterName'

    foreach ($item in $Pricing) {   
        $serviceInfo = @{"Operation"=$($item.Values[0]);"Price"="$($item.Group[0].retailPrice)";"PerOperation"="$($item.Group[0].unitOfMeasure)"}
        $empty = $list.Add($serviceInfo)
    }
    return $list
}

Function convertFrom-Terraform($body)
{
    $list = New-Object System.Collections.ArrayList
    $tfResources = $body.resource_changes
    foreach ($resource in $tfResources) {
        $resourceType = (($resource.type).replace("azurerm_", "")).replace("_", " ")
        $res = @{"ServiceName"=$resourceType;"resourceChangement"= $resource.change.after}
        $empty = $list.Add($res)
    }
    return $list
}


$jsonList = New-Object System.Collections.ArrayList

$serviceProperties = Get-Content -Raw -Path "./HttpTrigger1/terraformEditorParameters.json" | ConvertFrom-Json
$resources = convertFrom-Terraform -body $Request.Body

foreach ($resource in $resources) {
    switch ($resource.ServiceName) {
        "key vault" {
            $jsonBase = @{}
            $serviceType = "Key Vault"
            $url = Get-DefaultUrl -serviceType $serviceType -serviceObject $resource.resourceChangement -serviceProperties $serviceProperties
            $list = Get-ServicePrice -url $url
            $jsonBase.Add("serviceType",$serviceType)
            $jsonBase.Add("serviceDetails",@($list))
            $jsonList.Add($jsonBase)
        }
        "app service plan" {
            $jsonBase = @{}
            $serviceType = "Azure App Service"
            $url = Get-DefaultUrl -serviceType $serviceType -serviceObject $resource.resourceChangement -serviceProperties $serviceProperties
            $list = Get-ServicePrice -url $url
            $jsonBase.Add("serviceType",$serviceType)
            $jsonBase.Add("serviceDetails",@($list))
            $jsonList.Add($jsonBase)
        }
        "storage account" {
            $jsonBase = @{}
            $serviceType = "Storage"
            $url = Get-StorageUrl -serviceType $serviceType -serviceObject $resource.resourceChangement -serviceProperties $serviceProperties
            $list = Get-ServicePrice -url $url
            $jsonBase.Add("serviceType",$serviceType)
            $jsonBase.Add("serviceDetails",@($list))
            $jsonList.Add($jsonBase)
        }
        Default {}
    }
}
$jsonFinal = ConvertTo-Json $jsonList -Depth 10

Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::OK
    Body = $jsonFinal
})