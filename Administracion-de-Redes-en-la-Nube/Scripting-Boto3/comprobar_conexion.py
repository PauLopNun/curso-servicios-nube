#!/usr/bin/env python3
# Comprueba que boto3 se conecta a AWS con las credenciales del Learner Lab y muestra la cuenta

import boto3
from botocore.exceptions import ClientError, NoCredentialsError

REGION = "us-east-1"

try:
    identidad = boto3.client("sts", region_name=REGION).get_caller_identity()
    print("Conectado a AWS")
    print(f"  Cuenta : {identidad['Account']}")
    print(f"  ARN    : {identidad['Arn']}")
    print(f"  Región : {REGION}")
    print("\nPara ver los recursos de la cuenta: python3 listar_recursos.py")

except NoCredentialsError:
    print("No se encuentran credenciales: revisa ~/.aws/credentials")
except ClientError as e:
    print(f"Error de AWS: {e.response['Error']['Code']} - {e.response['Error']['Message']}")
    print("Si el token ha caducado, reinicia el lab y pega credenciales nuevas en ~/.aws/credentials")
