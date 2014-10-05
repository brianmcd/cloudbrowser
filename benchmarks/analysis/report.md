# Benchmark ${testId} Report

Application endpoint : ${clientSetting.appAddress}

- Server starts at ${baseTime}
- Bechmark clients start sending events after ${clientStart}ms
- All clients ended after ${clientEnd}ms
- Clients sent events for ${clientElapsed}ms.
- ${clientSetting.processCount} client process(es) mimicking ${clientSetting.total.clientCount} clients, ${clientSetting.total.talkerCount} talkers
- ${serverSetting.workerCount} cloudbrowser workers


## Benchmark client configuration

Config file : ${clientSetting.configFile}

### Total

| app instance | browser | client | batch size |
| ---- | ---- | ---- | ---- |
| ${clientSetting.total.appInstanceCount} | ${clientSetting.total.browserCount} | ${clientSetting.total.clientCount} | ${clientSetting.total.batchSize}

<% if(clientSetting.processCount > 1) { %>
### For each client process

| app instance | browser | client | batch size |
| ----         | ----    | ----   | ----       |
| ${clientSetting.total.appInstanceCount} | ${clientSetting.total.browserCount} | ${clientSetting.total.clientCount} | ${clientSetting.total.batchSize}

<% } %>

## Stats

### Process Event
<% cstats=stats.total['client_request_eventProcess'] %>

| Rate | Latency | Count | Error Count |
| ---- | ----    | ----  | ----        |
| ${ cstats.totalRate } | ${cstats.totalAvg} | ${cstats.count} |${cstats.errorCount} |

<% cstats=stats.total['client_request_clientEvent'] %>
client event count: ${cstats.count}
<% cstats=stats.total['client_request_serverEvent'] %>
server event count: ${cstats.count}

### Resource Usage (during clients sending events)

${resourceUsageTable}

### Config File Content

```
${configFileContent}
```

