import sys
print('[STARTUP] agent.py loading...', flush=True)

try:
    import json
    import os
    import re
    import logging
    import boto3
    from starlette.applications import Starlette
    from starlette.responses import JSONResponse
    from starlette.routing import Route
    import uvicorn
except Exception as e:
    print(f'[STARTUP] IMPORT ERROR: {e}', flush=True)
    raise

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)
handler = logging.StreamHandler(sys.stdout)
handler.setLevel(logging.INFO)
logger.addHandler(handler)

MODEL_ID = os.environ.get('MODEL_ID', 'us.amazon.nova-pro-v1:0')
OUTPUT_BUCKET = os.environ.get('OUTPUT_BUCKET', '')
MEMORY_ID = os.environ.get('MEMORY_ID', '')
SIMILARITY_THRESHOLD = float(os.environ.get('SIMILARITY_THRESHOLD', '0.95'))

print(f'[STARTUP] GATEWAY_URL = {os.environ.get("GATEWAY_URL", "NOT SET")}', flush=True)
print(f'[STARTUP] OUTPUT_BUCKET = {OUTPUT_BUCKET}', flush=True)
print(f'[STARTUP] MEMORY_ID = {MEMORY_ID}', flush=True)
print(f'[STARTUP] SIMILARITY_THRESHOLD = {SIMILARITY_THRESHOLD}', flush=True)

SYSTEM_PROMPT = f"""You are a security findings deduplication and prioritization agent.

TASK: Given raw security findings, you must:
1. Group findings that share the same root cause
2. Use similarity threshold {SIMILARITY_THRESHOLD}
3. Prioritize groups by BUSINESS IMPACT, not default severity labels

PRIORITIZATION RULES:
- PII/customer-data resources: +40 priority points
- Production environment: +30 priority points
- Non-production environment: -30 priority points
- Public access exposure: +25 priority points

OUTPUT FORMAT (strict JSON):
{{
  \"total_raw_findings\": <number>,
  \"groups\": [
    {{
      \"title\": \"<root cause>\",
      \"root_cause\": \"<CVE or misconfiguration>\",
      \"severity\": \"<original severity>\",
      \"resource_type\": \"<AWS resource type>\",
      \"data_classification\": \"<PII|internal|unknown>\",
      \"environment\": \"<production|non-production>\",
      \"member_count\": <number>,
      \"priority_score\": <number>,
      \"priority_rank\": <rank>
    }}
  ],
  \"threshold_used\": {SIMILARITY_THRESHOLD}
}}"""


def invoke_gateway_tool(target_name, payload=None):
    """Invoke a Gateway tool target via MCP protocol with SigV4."""
    gateway_url = os.environ.get('GATEWAY_URL', '')
    if not gateway_url:
        return {'error': 'GATEWAY_URL not configured'}
    try:
        import urllib.request
        from botocore.auth import SigV4Auth
        from botocore.awsrequest import AWSRequest

        # TODO: Fix the MCP payload structure
        # Reference: https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/gateway-using-mcp-call.html#gateway-using-mcp-call-examples
        mcp_payload = json.dumps({
            'jsonrpc': '2.0',
            'id': f'call-{target_name}',
            'method': 'tools/call',
            'params': {
                'name': target_name,
                'arguments': payload or {}
            }
        }).encode('utf-8')

        session = boto3.Session()
        credentials = session.get_credentials().get_frozen_credentials()
        region = session.region_name or os.environ.get('AWS_REGION', 'us-east-1')

        request = AWSRequest(method='POST', url=gateway_url, data=mcp_payload,
                             headers={'Content-Type': 'application/json'})
        SigV4Auth(credentials, 'bedrock-agentcore', region).add_auth(request)

        req = urllib.request.Request(
            gateway_url, data=mcp_payload,
            headers=dict(request.headers), method='POST'
        )
        with urllib.request.urlopen(req, timeout=30) as resp:
            result = json.loads(resp.read().decode('utf-8'))

        # Check for JSON-RPC error response
        if 'error' in result:
            logger.error(f'Gateway returned error for {target_name}: {result["error"]}')
            return {'error': result['error']}

        content = result.get('result', {}).get('content', [])
        if content:
            text = content[0].get('text', '{}')
            return json.loads(text) if isinstance(text, str) else text
        return result
    except Exception as e:
        error_body = ''
        if hasattr(e, 'read'):
            try:
                error_body = e.read().decode('utf-8')
            except Exception:
                pass
        logger.error(f'Gateway invocation failed for {target_name}: {e} | Body: {error_body[:500]}')
        return {'error': f'{str(e)[:100]} | {error_body[:100]}'}


def list_available_tools():
    """List all available tools on the Gateway via MCP tools/list."""
    gateway_url = os.environ.get('GATEWAY_URL', '')
    if not gateway_url:
        logger.warning('GATEWAY_URL not set, cannot list tools')
        return []
    try:
        import urllib.request
        from botocore.auth import SigV4Auth
        from botocore.awsrequest import AWSRequest

        mcp_payload = json.dumps({
            'jsonrpc': '2.0',
            'id': 'list-tools-request',
            'method': 'tools/list',
            'params': {}
        }).encode('utf-8')

        session = boto3.Session()
        credentials = session.get_credentials().get_frozen_credentials()
        region = session.region_name or os.environ.get('AWS_REGION', 'us-east-1')

        request = AWSRequest(method='POST', url=gateway_url, data=mcp_payload,
                             headers={'Content-Type': 'application/json'})
        SigV4Auth(credentials, 'bedrock-agentcore', region).add_auth(request)

        req = urllib.request.Request(
            gateway_url, data=mcp_payload,
            headers=dict(request.headers), method='POST'
        )
        with urllib.request.urlopen(req, timeout=15) as resp:
            result = json.loads(resp.read().decode('utf-8'))

        tools = result.get('result', {}).get('tools', [])
        tool_names = [t.get('name', 'unknown') for t in tools]
        logger.info(f'=== AVAILABLE GATEWAY TOOLS ({len(tool_names)}) ===')
        for name in tool_names:
            logger.info(f'  Tool: {name}')
        logger.info('=== END TOOL LIST ===')
        return tool_names
    except Exception as e:
        logger.error(f'Failed to list Gateway tools: {e}')
        return []


# List tools at startup so they appear in CloudWatch logs
# (moved to invocations handler for reliable logging)


def gather_findings():
    logger.info('=== GATHER FINDINGS START ===')
    logger.info(f'GATEWAY_URL: {os.environ.get("GATEWAY_URL", "NOT SET")}')
    findings_resp = invoke_gateway_tool('findings-collector___findings-collector')  # TODO: Add the correct tool name (check CloudWatch logs after first invocation to see available tool name for finding colector)
    logger.info(f'Raw resp keys: {list(findings_resp.keys()) if isinstance(findings_resp, dict) else "NOT DICT"}')
    logger.info(f'Raw resp (500): {str(findings_resp)[:500]}')

    if 'error' in findings_resp:
        logger.error(f'Gateway tool returned error: {findings_resp["error"]}')
        return []

    if 'body' in findings_resp and isinstance(findings_resp['body'], str):
        logger.info('Parsing nested body string...')
        findings_resp = json.loads(findings_resp['body'])
    findings = findings_resp.get('findings', [])
    logger.info(f'=== GATHER FINDINGS END: {len(findings)} findings ===')
    return findings


def enrich_with_threat_intel(findings):
    """Enrich CVE findings with threat intelligence data via Gateway tool."""
    logger.info('=== THREAT INTEL ENRICHMENT START ===')
    enrichment_resp = invoke_gateway_tool('threat-intel-enrichment___threat-intel-enrichment')

    if 'error' in enrichment_resp:
        logger.warning(f'Threat intel enrichment failed: {enrichment_resp["error"]} — continuing without enrichment')
        return findings

    if 'body' in enrichment_resp and isinstance(enrichment_resp['body'], str):
        enrichment_resp = json.loads(enrichment_resp['body'])

    enrichments = enrichment_resp.get('enrichments', [])
    if not enrichments:
        logger.info('No enrichment data returned')
        return findings

    intel_map = {e.get('cve_id'): e for e in enrichments if e.get('cve_id')}
    logger.info(f'Got threat intel for {len(intel_map)} CVEs')

    enriched_count = 0
    for finding in findings:
        title = finding.get('title', '')
        for cve_id, intel in intel_map.items():
            if cve_id in title:
                finding['threat_intel'] = intel
                enriched_count += 1
                break

    logger.info(f'=== THREAT INTEL ENRICHMENT END: {enriched_count}/{len(findings)} findings enriched ===')
    return findings


def analyze_with_bedrock(findings):
    bedrock = boto3.client('bedrock-runtime')
    prompt_text = (
        f'Here are {len(findings)} raw security findings. '
        f'Deduplicate them into groups by root cause (threshold: {SIMILARITY_THRESHOLD}), '
        f'then prioritize by business impact.\n\n'
        f'Raw findings:\n{json.dumps(findings[:50], indent=1)}\n\n'
        f'Group them and output the JSON result.'
    )
    response = bedrock.converse(
        modelId=MODEL_ID,
        system=[{'text': SYSTEM_PROMPT}],
        messages=[{'role': 'user', 'content': [{'text': prompt_text}]}],
        inferenceConfig={'maxTokens': 4096, 'temperature': 0.1}
    )
    return response['output']['message']['content'][0]['text']


def parse_json_response(text):
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        json_match = re.search(r'```(?:json)?\s*([\s\S]*?)```', text)
        if json_match:
            try:
                return json.loads(json_match.group(1))
            except json.JSONDecodeError:
                pass
        return {'groups': [], 'total_raw_findings': 0}


def persist_groups(report):
    """Persist deduplicated groups to DynamoDB via the group-writer Gateway tool."""
    groups = report.get('groups', [])
    if not groups:
        logger.info('No groups to persist')
        return

    logger.info(f'=== PERSIST GROUPS START ({len(groups)} groups) ===')
    writer_resp = invoke_gateway_tool('group-writer___group-writer', {'groups': groups})

    if 'error' in writer_resp:
        logger.warning(f'Group writer failed: {writer_resp["error"]} — continuing without persistence')
        return

    if 'body' in writer_resp and isinstance(writer_resp['body'], str):
        writer_resp = json.loads(writer_resp['body'])

    written = writer_resp.get('written', 0)
    logger.info(f'=== PERSIST GROUPS END: {written} groups written to DynamoDB ===')


def store_in_memory(report):
    """Store dedup session results in AgentCore Memory via create_event."""
    if not MEMORY_ID:
        logger.info('MEMORY_ID not configured, skipping memory storage')
        return
    try:
        from datetime import datetime, timezone
        data_client = boto3.client('bedrock-agentcore')

        group_count = len(report.get('groups', []))
        threshold = report.get('threshold_used', SIMILARITY_THRESHOLD)
        total = report.get('total_raw_findings', 0)
        session_id = f'dedup-session-{datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")}'

        data_client.create_event(
            memoryId=MEMORY_ID,
            actorId='dedup-agent',
            sessionId=session_id,
            eventTimestamp=datetime.now(timezone.utc),
            payload=[
                {
                    'conversational': {
                        'content': {'text': f'Deduplicate {total} security findings with threshold {threshold}'},
                        'role': 'USER'
                    }
                },
                {
                    'conversational': {
                        'content': {'text': f'Deduplication complete. Grouped {total} findings into {group_count} clusters using threshold {threshold}. Top groups: {json.dumps([g.get("title", "") for g in report.get("groups", [])[:5]])}'},
                        'role': 'ASSISTANT'
                    }
                }
            ]
        )
        logger.info(f'Stored dedup session in memory: {session_id} ({group_count} groups)')
    except Exception as e:
        logger.error(f'Failed to store in memory: {e}')


async def ping(request):
    return JSONResponse({'status': 'healthy'})


async def invocations(request):
    try:
        body = await request.body()
        payload = json.loads(body) if body else {}
        query = payload.get('prompt', 'Deduplicate all security findings')
        logger.info(f'Received invocation: {query[:100]}')

        # List available tools (logs them and returns names for error reporting)
        available_tools = list_available_tools()

        # Gather findings via Gateway
        findings = gather_findings()

        # If no findings were returned, report the error with available tools
        if not findings:
            error_msg = 'Failed to gather findings from Gateway. The tool call returned an error or empty response.'
            if available_tools:
                error_msg += f' Available tools on this Gateway: {available_tools}'
            else:
                error_msg += ' Could not list available tools either — check GATEWAY_URL configuration.'
            return JSONResponse({
                'error': error_msg,
                'available_tools': available_tools,
                'hint': 'Check the MCP payload structure and tool name in agent.py'
            })

        # Enrich findings with threat intelligence
        findings = enrich_with_threat_intel(findings)

        result_text = analyze_with_bedrock(findings)
        report = parse_json_response(result_text)

        report.setdefault('total_raw_findings', len(findings))
        report.setdefault('threshold_used', SIMILARITY_THRESHOLD)

        if OUTPUT_BUCKET:
            s3 = boto3.client('s3')
            s3.put_object(
                Bucket=OUTPUT_BUCKET,
                Key='dedup-results/groups.json',
                Body=json.dumps(report, indent=2),
                ContentType='application/json'
            )
            report['_stored_at'] = f's3://{OUTPUT_BUCKET}/dedup-results/groups.json'

        # Persist groups to DynamoDB via Gateway tool
        persist_groups(report)

        # Store session results in memory
        store_in_memory(report)

        return JSONResponse(report)
    except Exception as e:
        logger.error(f'Invocation failed: {e}')
        return JSONResponse({'error': str(e)}, status_code=500)


app = Starlette(routes=[
    Route('/ping', ping, methods=['GET']),
    Route('/invocations', invocations, methods=['POST']),
])

print('[STARTUP] Starting uvicorn on 0.0.0.0:8080...', flush=True)
uvicorn.run(app, host='0.0.0.0', port=8080)