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
      'Custom-ResidentSetSummary_CL': {
        columns: [
          {
            name: 'TimeGenerated'
            type: 'datetime'
          }
          {
            name: 'SnapshotTime'
            type: 'datetime'
          }
          {
            name: 'TraceProcessName'
            type: 'string'
          }
          {
            name: 'Process'
            type: 'string'
          }
          {
            name: 'MMList'
            type: 'string'
          }
          {
            name: 'PCategory'
            type: 'string'
          }
          {
            name: 'Description'
            type: 'string'
          }
          {
            name: 'PPriority'
            type: 'string'
          }
          {
            name: 'SizeMB'
            type: 'real'
          }
        ]
      }
      'Custom-Text-ResidentSetSummary_CL': {
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
            'Custom-Text-ResidentSetSummary_CL'
          ]
          filePatterns: [
            'C:\\HostmemLogs\\Resident_Set_Summary_Table*'
          ]
          format: 'text'
          settings: {
            text: {
              recordStartTimestampFormat: 'ISO 8601'
            }
          }
          name: 'Custom-Text-ResidentSetSummary_C'
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
          'Custom-Text-ResidentSetSummary_CL'
        ]
        destinations: [
          'la-workspace'
        ]
        transformKql: 'source | extend line=split([\'RawData\'],\'|\') | extend TimeGenerated = now() | where tostring(line[0]) != "Process Name" | project TimeGenerated, TraceProcessName=tostring(line[0]),Process=tostring(line[1]),MMList=tostring(line[2]),PCategory=tostring(line[3]),Description=tostring(line[4]),PPriority=tostring(line[5]),SnapshotTime=todatetime(line[6]),SizeMB=todouble(line[7])'
        outputStream: 'Custom-ResidentSetSummary_CL'
      }
      {
        streams: [
          'Microsoft-InsightsMetrics'
        ]
        destinations: [
          'azureMonitorMetrics-default'
        ]
        transformKql: 'source'
        outputStream: 'Microsoft-InsightsMetrics'
      }
    ]
  }
}
