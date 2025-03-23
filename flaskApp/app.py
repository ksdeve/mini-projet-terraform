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

# Vérifier et créer la table des utilisateurs si elle n'existe pas
cursor.execute("""
    CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE
    )
""")
conn.commit()

print("Table 'users' vérifiée/créée avec succès.")

# Connexion à Azure Blob Storage
STORAGE_ACCOUNT_NAME = os.getenv("STORAGE_ACCOUNT_NAME")
STORAGE_ACCOUNT_KEY = os.getenv("STORAGE_ACCOUNT_KEY")
CONTAINER_NAME = os.getenv("CONTAINER_NAME")

blob_service_client = BlobServiceClient(
    f"https://{STORAGE_ACCOUNT_NAME}.blob.core.windows.net",
    credential=STORAGE_ACCOUNT_KEY
)

# Routes CRUD pour les utilisateurs
@app.route('/user', methods=['POST'])
def create_user():
    """Créer un utilisateur."""
    try:
        cursor.execute("INSERT INTO users (name, email) VALUES (%s, %s)", (data['name'], data['email']))
        conn.commit()  # Valide la transaction
    except psycopg2.Error as e:
        conn.rollback()  # Annule la transaction en cas d'erreur
        print("Erreur SQL :", e)
    finally:
        cursor.close()  # Toujours fermer le curseur


@app.route('/user/<int:user_id>', methods=['GET'])
def get_user(user_id):
    """Lire un utilisateur par son ID."""
    cursor.execute("SELECT * FROM users WHERE id = %s", (user_id,))
    user = cursor.fetchone()
    if user:
        return jsonify({"id": user[0], "name": user[1], "email": user[2]}), 200
    else:
        return jsonify({"message": "User not found"}), 404

@app.route('/user/<int:user_id>', methods=['PUT'])
def update_user(user_id):
    """Mettre à jour un utilisateur."""
    data = request.get_json()
    cursor.execute("UPDATE users SET name = %s, email = %s WHERE id = %s", (data['name'], data['email'], user_id))
    conn.commit()
    return jsonify({"message": "User updated successfully"}), 200

@app.route('/user/<int:user_id>', methods=['DELETE'])
def delete_user(user_id):
    """Supprimer un utilisateur."""
    cursor.execute("DELETE FROM users WHERE id = %s", (user_id,))
    conn.commit()
    return jsonify({"message": "User deleted successfully"}), 200

# Routes pour l'upload et download de fichiers vers Azure Blob Storage
@app.route('/upload', methods=['POST'])
def upload_file():
    """Téléverser un fichier dans Azure Blob Storage."""
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

# Route pour lire tous les utilisateurs
@app.route('/users', methods=['GET'])
def read_users():
    """Lire tous les utilisateurs."""
    cursor.execute("SELECT * FROM users")
    users = cursor.fetchall()
    return jsonify([{"id": user[0], "name": user[1], "email": user[2]} for user in users]), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
