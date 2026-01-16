import paho.mqtt.client as mqtt
import pymysql
import sys

# --- Configurações Reais ---
MQTT_BROKER = "127.0.0.1"
MQTT_PORTA = 1883
MQTT_USER = "trilheiro_mqtt"
MQTT_PASS = "mapl_mqtt_2025"

MYSQL_HOST = "127.0.0.1"
MYSQL_USER = "mapl_user"
MYSQL_SENHA = "5an5un65@L"
MYSQL_BANCO = "aplicativotrilhamapl"

# Tópicos que compõem um pacote completo
# O sistema só grava quando TODOS estes campos estiverem preenchidos no buffer
CAMPOS_OBRIGATORIOS = {
    "id_pessoa", 
    "id_tag", 
    "id_leitor", 
    "time_stamp", 
    "gps_lat", 
    "gps_lon"
}


buffer_sessao = {}

def conectar_mysql():
    return pymysql.connect(
        host=MYSQL_HOST, 
        user=MYSQL_USER, 
        password=MYSQL_SENHA, 
        database=MYSQL_BANCO, 
        cursorclass=pymysql.cursors.DictCursor
    )

def gravar_no_banco(dados):
    """
    Grava os dados acumulados no banco de dados.
    """
    conexao = None
    try:
        conexao = conectar_mysql()
        with conexao.cursor() as cur:

            sql = """
                INSERT INTO eventos_passagem 
                (id_usuario, id_tag, timestamp_leitura, direcao) 
                VALUES (%s, %s, %s, 'ida')
            """
            cur.execute(sql, (
                dados['id_pessoa'], 
                dados['id_tag'], 
                dados['time_stamp']
            ))
            conexao.commit()
            print(f"[PELMS] REGISTRO SALVO: Usuário {dados['id_pessoa']} na Tag {dados['id_tag']} (Leitor {dados['id_leitor']})")
            
    except pymysql.Error as e:
        print(f"[PELMS] Erro de SQL: {e}")
    finally:
        if conexao: conexao.close()

def verificar_completude():
    """
    Verifica se o buffer tem todos os 6 campos necessários.
    Se sim, grava e limpa.
    """
    global buffer_sessao
    
    chaves_presentes = set(buffer_sessao.keys())
    
    if CAMPOS_OBRIGATORIOS.issubset(chaves_presentes):
        gravar_no_banco(buffer_sessao)
        buffer_sessao = {} 
        print("[PELMS] Buffer limpo. Aguardando novos dados...")

def on_connect(client, userdata, flags, rc):
    if rc == 0:
        print("[PELMS] Conectado ao Broker. Monitorando tópicos reais...")
        topics = [
            ("trilha/id_pessoa", 0),
            ("trilha/id_tag", 0),
            ("trilha/id_leitor", 0),
            ("trilha/time_stamp", 0),
            ("trilha/gps_lat", 0),
            ("trilha/gps_lon", 0),
            ("trilha/eventos/passagem", 0) 
        ]
        client.subscribe(topics)
    else:
        print(f"[PELMS] Falha na conexão: {rc}")

def on_message(client, userdata, msg):
    global buffer_sessao
    
    topic = msg.topic
    payload = msg.payload.decode('utf-8')
    
    print(f"[RX] {topic}: {payload}")

    if topic == "trilha/eventos/passagem":
        import json
        try:
            gravar_no_banco(json.loads(payload)) 
        except: pass
        return

    # Rota 2: Protocolo LoRa Fragmentado 
    campo = topic.split('/')[-1]
    
    if campo in CAMPOS_OBRIGATORIOS:
        buffer_sessao[campo] = payload
        
        verificar_completude()

# --- Inicialização ---
client = mqtt.Client(client_id="linux_production_listener")
client.username_pw_set(MQTT_USER, MQTT_PASS)
client.on_connect = on_connect
client.on_message = on_message

try:
    client.connect(MQTT_BROKER, MQTT_PORTA, 60)
    client.loop_forever()
except KeyboardInterrupt:
    print("\n[PELMS] Serviço parando...")
