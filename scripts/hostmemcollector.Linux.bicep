targetScope = 'resourceGroup'

param location string = resourceGroup().location
param ruleName string
param dataCollectionEndpointId string
param logAnalyticsWorkspaceId string

resource hostmemcollectorrule 'Microsoft.Insights/dataCollectionRules@2022-06-01' = {
  name: ruleName
  location: location
  properties: {
    dataCollectionEndpointId: dataCollectionEndpointId
    streamDeclarations: {
      'Custom-CgroupMem_CL': {
        columns: [
          {
            name: 'TimeGenerated'
            type: 'datetime'
          }
          {
            name: 'Cgroup'
            type: 'string'
          }
          {
            name: 'ContainerName'
            type: 'string'
          }
          {
            name: 'PodName'
            type: 'string'
          }
          {
            name: 'Namespace'
            type: 'string'
          }
          {
            name: 'MemoryUsage'
            type: 'real'
          }
          {
            name: 'TotalCache'
            type: 'real'
          }
        ]
      }
      'Custom-Text-CgroupMem_CL': {
        columns: [
          {
            name: 'TimeGenerated'
            type: 'datetime'
          }
          {
            name: 'RawData'
            type: 'string'
          }
        ]
      }
    }
    dataSources: {
      performanceCounters: [
        {
          streams: [
            'Microsoft-InsightsMetrics'
          ]
          samplingFrequencyInSeconds: 60
          counterSpecifiers: [
            '\\System\\Processes'
            '\\Process(_Total)\\Thread Count'
            '\\Process(_Total)\\Handle Count'
            '\\System\\System Up Time'
            '\\System\\Context Switches/sec'
            '\\System\\Processor Queue Length'
            '\\Memory\\% Committed Bytes In Use'
            '\\Memory\\Available Bytes'
            '\\Memory\\Committed Bytes'
            '\\Memory\\Cache Bytes'
            '\\Memory\\Pool Paged Bytes'
            '\\Memory\\Pool Nonpaged Bytes'
            '\\Memory\\Pages/sec'
            '\\Memory\\Page Faults/sec'
            '\\Process(_Total)\\Working Set'
            '\\Process(_Total)\\Working Set - Private'
            '\\LogicalDisk(_Total)\\% Free Space'
            '\\LogicalDisk(_Total)\\Free Megabyte'
          ]
          name: 'perfCounterDataSource60'
        }
      ]
      logFiles: [
        {
          streams: [
            'Custom-Text-CgroupMem_CL'
          ]
          filePatterns: [
            '/root/hostmem/cgroup_memory_usage*'
          ]
          format: 'text'
          settings: {
            text: {
              recordStartTimestampFormat: 'ISO 8601'
            }
          }
          name: 'Custom-Text-CgroupMem_C'
        }
      ]
    }
    destinations: {
      logAnalytics: [
        {
          workspaceResourceId: logAnalyticsWorkspaceId
          name: 'la-workspace'
        }
      ]
      azureMonitorMetrics: {
        name: 'azureMonitorMetrics-default'
      }
    }
    dataFlows: [
      {
        streams: [
          'Custom-Text-CgroupMem_CL'
        ]
        destinations: [
          'la-workspace'
        ]
        transformKql: 'source | extend line=split([\'RawData\'],\'|\') | where tostring(line[0]) != "Cgroup" | project Cgroup=tostring(line[0]),MemoryUsage=todouble(line[1]),TotalCache=todouble(line[2]),ContainerName=tostring(line[3]),PodName=tostring(line[4]),Namespace=tostring(line[5]),TimeGenerated=todatetime(line[6])'
        outputStream: 'Custom-CgroupMem_CL'
      }
    ]
  }
}
