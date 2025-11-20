# DNS Agent Test Payload Formats

## Runtime ID: a208194_chatops_route_dns_lookup-Zg3E6G5ZDV

Based on code analysis, the DNS agent supports multiple JSON payload formats:

## Format 1: Direct Event Format (Recommended)
```json
{"dns_name": "microsoft.com"}
```

## Format 2: API Gateway Body Format
```json
{
  "body": "{\"dns_name\": \"microsoft.com\"}"
}
```

## Format 3: API Gateway Body Format (Object)
```json
{
  "body": {
    "dns_name": "microsoft.com"
  }
}
```

## Format 4: Legacy Lex Format (Backward Compatibility)
```json
{
  "currentIntent": {
    "slots": {
      "DNS_record": "microsoft.com"
    }
  }
}
```

## Format 5: Agent Core Runtime Wrapper Format
```json
{
  "input": {
    "dns_name": "microsoft.com"
  }
}
```

## Format 6: Bedrock Agent Format
```json
{
  "actionGroup": "dns-lookup",
  "parameters": {
    "dns_name": "microsoft.com"
  }
}
```

## Format 7: Runtime Event Format
```json
{
  "requestId": "test-123",
  "input": {
    "dns_name": "microsoft.com"
  }
}
```

## Test Domains to Try:
- microsoft.com
- google.com  
- amazon.com
- github.com
- stackoverflow.com

## Testing Instructions:
1. Go to AWS Console → Amazon Bedrock → Agent Core Runtimes
2. Select runtime: a208194_chatops_route_dns_lookup-Zg3E6G5ZDV
3. Try each format above starting with Format 1
4. If Format 1 fails, try Format 5 (Agent Core wrapper)
5. Document which format works for team integration

## Expected Success Response:
```json
{
  "success": true,
  "message": "DNS lookup completed successfully",
  "data": {
    "domain": "microsoft.com.",
    "records": [/* DNS records array */]
  }
}
```

## Debugging Notes:
- 404 errors may indicate payload format mismatch
- 500 errors likely indicate environment/SSM issues  
- Health check should now work with /ping endpoint fix