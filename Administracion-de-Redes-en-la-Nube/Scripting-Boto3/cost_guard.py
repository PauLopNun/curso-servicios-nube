import boto3
from datetime import datetime, timezone
from botocore.exceptions import ClientError

REGION = "us-east-1"
LIMITE_PRESUPUESTO_USD = 10.0
MAX_HORAS_VIDA = 4.0  # Máximo tiempo continuo para cualquier instancia

# Precios aproximados por hora en us-east-1 (bajo demanda)
PRECIOS_EC2 = {
    "t2.micro": 0.0116,
    "t2.small": 0.023,
    "t3.micro": 0.0104,
    "t3.small": 0.0208,
    "t3.medium": 0.0416,
}
PRECIO_DEFECTO_HORA = 0.05

ec2 = boto3.client("ec2", region_name=REGION)
cw = boto3.client("cloudwatch", region_name=REGION)


def obtener_facturacion_base() -> float:
    """Lee el último dato oficial de CloudWatch para EstimatedCharges."""
    ahora = datetime.now(timezone.utc)
    try:
        res = cw.get_metric_data(
            MetricDataQueries=[{
                "Id": "billing",
                "MetricStat": {
                    "Metric": {
                        "Namespace": "AWS/Billing",
                        "MetricName": "EstimatedCharges",
                        "Dimensions": [{"Name": "Currency", "Value": "USD"}]
                    },
                    "Period": 21600,
                    "Stat": "Maximum"
                },
                "ReturnData": True
            }],
            StartTime=ahora.replace(hour=0, minute=0, second=0),
            EndTime=ahora
        )
        valores = res["MetricDataResults"][0]["Values"]
        return valores[0] if valores else 0.0
    except ClientError as e:
        print(f"Aviso: no se pudo leer EstimatedCharges ({e.response['Error']['Code']})")
        return 0.0


def limpiar_recursos_huerfanos():
    """Elimina volúmenes EBS sueltos y libera IPs elásticas no asociadas."""
    # 1. Volúmenes EBS huérfanos
    vols = ec2.describe_volumes(Filters=[{"Name": "status", "Values": ["available"]}])
    for v in vols.get("Volumes", []):
        vid = v["VolumeId"]
        print(f"Limpieza: Eliminando volumen EBS huérfano {vid}...")
        ec2.delete_volume(VolumeId=vid)

    # 2. IPs Elásticas sin máquina asignada
    ips = ec2.describe_addresses()
    for addr in ips.get("Addresses", []):
        if "InstanceId" not in addr and "NetworkInterfaceId" not in addr:
            alloc_id = addr.get("AllocationId")
            if alloc_id:
                print(f"Limpieza: Liberando Elastic IP huérfana {addr.get('PublicIp')}...")
                ec2.release_address(AllocationId=alloc_id)


def lambda_handler(event, context):
    ahora = datetime.now(timezone.utc)
    gasto_base = obtener_facturacion_base()
    
    # Inspeccionar instancias en ejecución
    instancias = ec2.describe_instances(
        Filters=[{"Name": "instance-state-name", "Values": ["running"]}]
    )
    
    coste_en_vuelo = 0.0
    instancias_activas = []
    instancias_excedidas_ttl = []
    
    for r in instancias.get("Reservations", []):
        for inst in r.get("Instances", []):
            i_id = inst["InstanceId"]
            i_type = inst["InstanceType"]
            launch_time = inst["LaunchTime"]
            tags = {t["Key"]: t["Value"] for t in inst.get("Tags", [])}
            
            instancias_activas.append(i_id)
            horas_viva = (ahora - launch_time).total_seconds() / 3600.0
            
            # Cálculo de coste estimado
            precio_h = PRECIOS_EC2.get(i_type, PRECIO_DEFECTO_HORA)
            coste_en_vuelo += horas_viva * precio_h
            
            # Verificación de TTL (ignora si tiene Tag KeepAlive=true)
            if horas_viva >= MAX_HORAS_VIDA and tags.get("KeepAlive", "").lower() != "true":
                instancias_excedidas_ttl.append(i_id)

    gasto_total = gasto_base + coste_en_vuelo
    print(f"Facturado: ${gasto_base:.2f} | En vuelo: ${coste_en_vuelo:.2f} | Total: ${gasto_total:.2f}")

    # Condición 1: Superación de presupuesto global
    if gasto_total >= LIMITE_PRESUPUESTO_USD and instancias_activas:
        print(f"EMERGENCIA: Presupuesto superado (${gasto_total:.2f} >= ${LIMITE_PRESUPUESTO_USD}).")
        ec2.terminate_instances(InstanceIds=instancias_activas)
        limpiar_recursos_huerfanos()
        return

    # Condición 2: Instancias olvidadas por TTL
    if instancias_excedidas_ttl:
        print(f"TTL Excedido (>{MAX_HORAS_VIDA}h): Terminando instancias {instancias_excedidas_ttl}")
        ec2.terminate_instances(InstanceIds=instancias_excedidas_ttl)

    # Barrido preventivo de costes pasivos
    limpiar_recursos_huerfanos()

if __name__ == "__main__":
    print("Iniciando escaneo de costes y recursos...")
    lambda_handler(None, None)
    print("Escaneo finalizado.")