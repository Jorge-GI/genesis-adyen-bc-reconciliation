targetScope = 'resourceGroup'

@description('Short lowercase deployment prefix, for example giadyentest.')
param prefix string
param location string = resourceGroup().location
param environmentName string
param adyenMerchantAccount string
@allowed(['test', 'live'])
param adyenEnvironment string
param ingressAuthClientId string
@description('Client application ID used by Adyen to request ingress access tokens.')
param adyenWebhookClientId string
param ingressAuthIssuer string
param ingressAuthAudience string
param businessCentralTenantId string
param businessCentralEnvironmentName string
param businessCentralCompanyId string
param businessCentralClientId string
param hmacCurrentSecretName string = 'adyen-hmac-current'
param hmacPreviousSecretName string = 'adyen-hmac-previous'
param businessCentralClientSecretName string = 'business-central-client-secret'
param reportUsernameSecretName string = 'adyen-report-username'
param reportPasswordSecretName string = 'adyen-report-password'
param reportTimeZoneId string = 'Europe/Berlin'
@minValue(1)
param rawWebhookRetentionDays int = 90
@minValue(1)
param reportRetentionDays int = 400
param reportAllowedHost string = adyenEnvironment == 'live'
  ? 'ca-live.adyen.com'
  : 'ca-test.adyen.com'

var normalizedPrefix = toLower(replace(prefix, '-', ''))
var normalizedEnvironmentName = toLower(replace(environmentName, '-', ''))
var uniqueSuffix = uniqueString(resourceGroup().id, prefix, environmentName)
var ingressHostStorageName = take('${normalizedPrefix}ih${uniqueSuffix}', 24)
var workerHostStorageName = take('${normalizedPrefix}wh${uniqueSuffix}', 24)
var archiveStorageName = take('${normalizedPrefix}ar${uniqueSuffix}', 24)
var serviceBusName = take('${prefix}-${environmentName}-${uniqueSuffix}', 50)
var ingressName = take('${prefix}-${environmentName}-ingress-${uniqueSuffix}', 60)
var workerName = take('${prefix}-${environmentName}-worker-${uniqueSuffix}', 60)
var ingressVaultName = take('${normalizedPrefix}ih${normalizedEnvironmentName}${uniqueSuffix}', 24)
var workerVaultName = take('${normalizedPrefix}wk${normalizedEnvironmentName}${uniqueSuffix}', 24)
var planName = '${prefix}-${environmentName}-functions'
var webhookQueueName = 'adyen-webhook-events'
var reportQueueName = 'adyen-report-jobs'

var serviceBusSenderRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '69a216fc-b8fb-44d8-bc22-1f3c2cd27a39')
var serviceBusReceiverRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0')
var blobOwnerRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b')
var blobContributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
var tableContributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3')
var keyVaultSecretsUserRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: '${prefix}-${environmentName}-logs'
  location: location
  properties: {
    retentionInDays: 30
    sku: { name: 'PerGB2018' }
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${prefix}-${environmentName}-insights'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}

resource ingressHostStorage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: ingressHostStorageName
  location: location
  kind: 'StorageV2'
  sku: { name: 'Standard_LRS' }
  properties: {
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

resource workerHostStorage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: workerHostStorageName
  location: location
  kind: 'StorageV2'
  sku: { name: 'Standard_LRS' }
  properties: {
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

resource archiveStorage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: archiveStorageName
  location: location
  kind: 'StorageV2'
  sku: { name: 'Standard_LRS' }
  properties: {
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: archiveStorage
  name: 'default'
  properties: {
    deleteRetentionPolicy: { enabled: true, days: 14 }
    containerDeleteRetentionPolicy: { enabled: true, days: 14 }
  }
}

resource rawWebhookContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'adyen-webhooks-raw'
  properties: { publicAccess: 'None' }
}

resource reportsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'adyen-reports'
  properties: { publicAccess: 'None' }
}

resource archiveLifecycle 'Microsoft.Storage/storageAccounts/managementPolicies@2023-05-01' = {
  parent: archiveStorage
  name: 'default'
  properties: {
    policy: {
      rules: [
        {
          name: 'delete-expired-raw-webhooks'
          enabled: true
          type: 'Lifecycle'
          definition: {
            filters: {
              blobTypes: [ 'blockBlob' ]
              prefixMatch: [ 'adyen-webhooks-raw/' ]
            }
            actions: {
              baseBlob: {
                delete: { daysAfterModificationGreaterThan: rawWebhookRetentionDays }
              }
            }
          }
        }
        {
          name: 'delete-expired-reports'
          enabled: true
          type: 'Lifecycle'
          definition: {
            filters: {
              blobTypes: [ 'blockBlob' ]
              prefixMatch: [ 'adyen-reports/' ]
            }
            actions: {
              baseBlob: {
                delete: { daysAfterModificationGreaterThan: reportRetentionDays }
              }
            }
          }
        }
      ]
    }
  }
}

resource serviceBus 'Microsoft.ServiceBus/namespaces@2024-01-01' = {
  name: serviceBusName
  location: location
  sku: { name: 'Standard', tier: 'Standard' }
  properties: {
    minimumTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
  }
}

resource webhookQueue 'Microsoft.ServiceBus/namespaces/queues@2024-01-01' = {
  parent: serviceBus
  name: webhookQueueName
  properties: {
    requiresDuplicateDetection: true
    duplicateDetectionHistoryTimeWindow: 'PT1H'
    lockDuration: 'PT1M'
    maxDeliveryCount: 10
    deadLetteringOnMessageExpiration: true
    defaultMessageTimeToLive: 'P14D'
  }
}

resource reportQueue 'Microsoft.ServiceBus/namespaces/queues@2024-01-01' = {
  parent: serviceBus
  name: reportQueueName
  properties: {
    requiresDuplicateDetection: true
    duplicateDetectionHistoryTimeWindow: 'P1D'
    lockDuration: 'PT5M'
    maxDeliveryCount: 10
    deadLetteringOnMessageExpiration: true
    defaultMessageTimeToLive: 'P14D'
  }
}

resource ingressKeyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: ingressVaultName
  location: location
  properties: {
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    enablePurgeProtection: true
    publicNetworkAccess: 'Enabled'
    sku: { family: 'A', name: 'standard' }
  }
}

resource workerKeyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: workerVaultName
  location: location
  properties: {
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    enablePurgeProtection: true
    publicNetworkAccess: 'Enabled'
    sku: { family: 'A', name: 'standard' }
  }
}

resource functionPlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: planName
  location: location
  kind: 'linux'
  sku: { name: 'Y1', tier: 'Dynamic' }
  properties: { reserved: true }
}

resource ingress 'Microsoft.Web/sites@2023-12-01' = {
  name: ingressName
  location: location
  kind: 'functionapp,linux'
  identity: { type: 'SystemAssigned' }
  properties: {
    serverFarmId: functionPlan.id
    httpsOnly: true
    clientAffinityEnabled: false
    siteConfig: {
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      linuxFxVersion: 'DOTNET-ISOLATED|8.0'
      alwaysOn: false
    }
  }
}

resource ingressSettings 'Microsoft.Web/sites/config@2023-12-01' = {
  parent: ingress
  name: 'appsettings'
  properties: {
    FUNCTIONS_EXTENSION_VERSION: '~4'
    FUNCTIONS_WORKER_RUNTIME: 'dotnet-isolated'
    AzureWebJobsStorage__accountName: ingressHostStorage.name
    ServiceBus__fullyQualifiedNamespace: '${serviceBus.name}.servicebus.windows.net'
    WebhookQueueName: webhookQueue.name
    APPLICATIONINSIGHTS_CONNECTION_STRING: appInsights.properties.ConnectionString
    Ingress__RequireEasyAuthPrincipal: 'true'
    Adyen__MerchantAccount: adyenMerchantAccount
    Adyen__Environment: adyenEnvironment
    Adyen__HmacKeys__0: '@Microsoft.KeyVault(SecretUri=${ingressKeyVault.properties.vaultUri}secrets/${hmacCurrentSecretName})'
    Adyen__HmacKeys__1: '@Microsoft.KeyVault(SecretUri=${ingressKeyVault.properties.vaultUri}secrets/${hmacPreviousSecretName})'
  }
}

resource ingressAuth 'Microsoft.Web/sites/config@2023-12-01' = {
  parent: ingress
  name: 'authsettingsV2'
  properties: {
    platform: { enabled: true, runtimeVersion: '~1' }
    globalValidation: {
      requireAuthentication: true
      unauthenticatedClientAction: 'Return401'
    }
    identityProviders: {
      azureActiveDirectory: {
        enabled: true
        registration: {
          clientId: ingressAuthClientId
          openIdIssuer: ingressAuthIssuer
        }
        validation: {
          allowedAudiences: [ ingressAuthAudience ]
          defaultAuthorizationPolicy: {
            allowedApplications: [ adyenWebhookClientId ]
          }
        }
      }
    }
    httpSettings: { requireHttps: true }
  }
}

resource worker 'Microsoft.Web/sites@2023-12-01' = {
  name: workerName
  location: location
  kind: 'functionapp,linux'
  identity: { type: 'SystemAssigned' }
  properties: {
    serverFarmId: functionPlan.id
    httpsOnly: true
    clientAffinityEnabled: false
    siteConfig: {
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      linuxFxVersion: 'DOTNET-ISOLATED|8.0'
      alwaysOn: false
    }
  }
}

resource workerSettings 'Microsoft.Web/sites/config@2023-12-01' = {
  parent: worker
  name: 'appsettings'
  properties: {
    FUNCTIONS_EXTENSION_VERSION: '~4'
    FUNCTIONS_WORKER_RUNTIME: 'dotnet-isolated'
    AzureWebJobsStorage__accountName: workerHostStorage.name
    BlobServiceUri: archiveStorage.properties.primaryEndpoints.blob
    ServiceBus__fullyQualifiedNamespace: '${serviceBus.name}.servicebus.windows.net'
    WebhookQueueName: webhookQueue.name
    ReportQueueName: reportQueue.name
    APPLICATIONINSIGHTS_CONNECTION_STRING: appInsights.properties.ConnectionString
    BusinessCentral__TenantId: businessCentralTenantId
    BusinessCentral__EnvironmentName: businessCentralEnvironmentName
    BusinessCentral__CompanyId: businessCentralCompanyId
    BusinessCentral__ClientId: businessCentralClientId
    BusinessCentral__ClientSecret: '@Microsoft.KeyVault(SecretUri=${workerKeyVault.properties.vaultUri}secrets/${businessCentralClientSecretName})'
    Reports__Username: '@Microsoft.KeyVault(SecretUri=${workerKeyVault.properties.vaultUri}secrets/${reportUsernameSecretName})'
    Reports__Password: '@Microsoft.KeyVault(SecretUri=${workerKeyVault.properties.vaultUri}secrets/${reportPasswordSecretName})'
    Reports__Environment: adyenEnvironment
    Reports__TimeZoneId: reportTimeZoneId
    Reports__AllowedHosts__0: reportAllowedHost
  }
}

resource ingressWebhookSender 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(webhookQueue.id, ingress.id, serviceBusSenderRoleId)
  scope: webhookQueue
  properties: { principalId: ingress.identity.principalId, roleDefinitionId: serviceBusSenderRoleId, principalType: 'ServicePrincipal' }
}
resource workerWebhookReceiver 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(webhookQueue.id, worker.id, serviceBusReceiverRoleId)
  scope: webhookQueue
  properties: { principalId: worker.identity.principalId, roleDefinitionId: serviceBusReceiverRoleId, principalType: 'ServicePrincipal' }
}
resource workerReportSender 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(reportQueue.id, worker.id, serviceBusSenderRoleId)
  scope: reportQueue
  properties: { principalId: worker.identity.principalId, roleDefinitionId: serviceBusSenderRoleId, principalType: 'ServicePrincipal' }
}
resource workerReportReceiver 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(reportQueue.id, worker.id, serviceBusReceiverRoleId)
  scope: reportQueue
  properties: { principalId: worker.identity.principalId, roleDefinitionId: serviceBusReceiverRoleId, principalType: 'ServicePrincipal' }
}

resource ingressHostBlobOwnerRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(ingressHostStorage.id, ingress.id, blobOwnerRoleId)
  scope: ingressHostStorage
  properties: { principalId: ingress.identity.principalId, roleDefinitionId: blobOwnerRoleId, principalType: 'ServicePrincipal' }
}
resource ingressHostTableRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(ingressHostStorage.id, ingress.id, tableContributorRoleId)
  scope: ingressHostStorage
  properties: { principalId: ingress.identity.principalId, roleDefinitionId: tableContributorRoleId, principalType: 'ServicePrincipal' }
}
resource workerHostBlobOwnerRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(workerHostStorage.id, worker.id, blobOwnerRoleId)
  scope: workerHostStorage
  properties: { principalId: worker.identity.principalId, roleDefinitionId: blobOwnerRoleId, principalType: 'ServicePrincipal' }
}
resource workerHostTableRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(workerHostStorage.id, worker.id, tableContributorRoleId)
  scope: workerHostStorage
  properties: { principalId: worker.identity.principalId, roleDefinitionId: tableContributorRoleId, principalType: 'ServicePrincipal' }
}
resource workerArchiveBlobRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(archiveStorage.id, worker.id, blobContributorRoleId)
  scope: archiveStorage
  properties: { principalId: worker.identity.principalId, roleDefinitionId: blobContributorRoleId, principalType: 'ServicePrincipal' }
}
resource ingressVaultRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(ingressKeyVault.id, ingress.id, keyVaultSecretsUserRoleId)
  scope: ingressKeyVault
  properties: { principalId: ingress.identity.principalId, roleDefinitionId: keyVaultSecretsUserRoleId, principalType: 'ServicePrincipal' }
}
resource workerVaultRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(workerKeyVault.id, worker.id, keyVaultSecretsUserRoleId)
  scope: workerKeyVault
  properties: { principalId: worker.identity.principalId, roleDefinitionId: keyVaultSecretsUserRoleId, principalType: 'ServicePrincipal' }
}

output ingressUrl string = 'https://${ingress.properties.defaultHostName}/api/adyen/webhooks/standard'
output ingressFunctionName string = ingress.name
output workerFunctionName string = worker.name
output serviceBusNamespace string = serviceBus.name
output ingressKeyVaultName string = ingressKeyVault.name
output workerKeyVaultName string = workerKeyVault.name
output ingressHostStorageAccountName string = ingressHostStorage.name
output workerHostStorageAccountName string = workerHostStorage.name
output archiveStorageAccountName string = archiveStorage.name
