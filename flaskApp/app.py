from flask import Flask, request, jsonify
import psycopg2
from azure.storage.blob import BlobServiceClient
import os
from dotenv import load_dotenv  # Import de dotenv

# Charger les variables d'environnement à partir du fichier .env
load_dotenv()

app = Flask(__name__)

# Connexion à PostgreSQL
conn = psycopg2.connect(
    dbname=os.getenv("DB_NAME"),
    user=os.getenv("DB_USER"),
    password=os.getenv("DB_PASSWORD"),
    host=os.getenv("DB_HOST"),
    port=os.getenv("DB_PORT"),
    sslmode='require',
)
cursor = conn.cursor()

# Vérifier et créer la table si elle n'existe pas
cursor.execute("""
    CREATE TABLE IF NOT EXISTS records (
        id SERIAL PRIMARY KEY,
        name TEXT NOT NULL,
        value TEXT NOT NULL
    )
""")
conn.commit()

print("Table 'records' vérifiée/créée avec succès.")

# Connexion à Azure Blob Storage
STORAGE_ACCOUNT_NAME = os.getenv("STORAGE_ACCOUNT_NAME")
STORAGE_ACCOUNT_KEY = os.getenv("STORAGE_ACCOUNT_KEY")
CONTAINER_NAME = os.getenv("CONTAINER_NAME")

blob_service_client = BlobServiceClient(
    f"https://{STORAGE_ACCOUNT_NAME}.blob.core.windows.net",
    credential=STORAGE_ACCOUNT_KEY
)

@app.route('/upload', methods=['POST'])
def upload_file():
    file = request.files['file']
    if file:
        # Créer un blob client
        blob_client = blob_service_client.get_blob_client(container=CONTAINER_NAME, blob=file.filename)
        
        # Télécharger le fichier sur Blob Storage
        blob_client.upload_blob(file, overwrite=True)

        return jsonify({"message": "File uploaded successfully"}), 200
    return jsonify({"error": "No file uploaded"}), 400

@app.route('/download/<filename>', methods=['GET'])
def download_file(filename):
    """Télécharger un fichier depuis Azure Blob Storage."""
    blob_client = blob_service_client.get_blob_client(container=CONTAINER_NAME, blob=filename)

    try:
        stream = blob_client.download_blob()
        return stream.readall(), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500
        

@app.route('/create', methods=['POST'])
def create_record():
    data = request.get_json()
    cursor.execute("INSERT INTO records (name, value) VALUES (%s, %s)", (data['name'], data['value']))
    conn.commit()
    return jsonify({"message": "Record created successfully"}), 201

@app.route('/read', methods=['GET'])
def read_record():
    cursor.execute("SELECT * FROM records")
    records = cursor.fetchall()
    return jsonify(records), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
