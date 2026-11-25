import json
import os
import boto3
from datetime import datetime, timezone

def lambda_handler(event, context):
    table_name = os.environ['TABLE_NAME']
    dynamodb = boto3.client('dynamodb')

    if 'groups' in event:
        body = event
    else:
        body = event.get('body', '{}')
        if isinstance(body, str):
            body = json.loads(body)

    groups = body.get('groups', [])
    if not groups:
        return {'statusCode': 400, 'body': json.dumps({'error': 'No groups provided'})}

    timestamp = datetime.now(timezone.utc).isoformat()
    written = 0

    for group in groups:
        group_id = group.get('root_cause', group.get('title', f'group-{written}'))
        dynamodb.put_item(
            TableName=table_name,
            Item={
                'group_id': {'S': group_id},
                'timestamp': {'S': timestamp},
                'title': {'S': group.get('title', '')},
                'severity': {'S': group.get('severity', '')},
                'member_count': {'N': str(group.get('member_count', 0))},
                'priority_score': {'N': str(group.get('priority_score', 0))},
                'priority_rank': {'N': str(group.get('priority_rank', 0))},
                'resource_type': {'S': group.get('resource_type', '')},
                'data_classification': {'S': group.get('data_classification', '')},
                'environment': {'S': group.get('environment', '')}
            }
        )
        written += 1

    return {'statusCode': 200, 'body': json.dumps({'written': written, 'timestamp': timestamp})}
